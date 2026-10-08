package com.triviarpg.rest;

import com.triviarpg.TriviaRpgApplication;
import com.triviarpg.model.InjectVoteRequest;
import com.triviarpg.model.RoundStartRequest;
import com.triviarpg.model.VoteState;
import com.triviarpg.service.VoteService;
import dev.getelements.elements.sdk.Element;
import dev.getelements.elements.sdk.ElementSupplier;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

/**
 * Chat-vote REST surface.
 *
 * GET  /vote        public state poll (the game polls this every few seconds)
 * POST /vote/round  open a new round   — control key required if configured
 * POST /vote/close  close early        — control key required if configured
 * POST /vote/inject simulate a chat vote (testing / non-Twitch play) — same gate
 *
 * When attribute trivia.control.key is empty, control endpoints are open
 * (useful for local dev); set it in production.
 */
@Tag(name = TriviaRpgApplication.OPENAPI_TAG)
@Path("/vote")
public class VoteEndpoint {

    public static final String CONTROL_KEY_HEADER = "X-Trivia-Key";

    private final Element element = ElementSupplier.getElementLocal(VoteEndpoint.class).get();
    private final VoteService voteService = element.getServiceLocator().getInstance(VoteService.class);

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Operation(
            summary = "Current vote round state",
            description = "Snapshot of the active (or most recent closed) round with live tallies."
    )
    @ApiResponse(responseCode = "200", description = "The current state",
            content = @Content(schema = @Schema(implementation = VoteState.class)))
    public VoteState getState() {
        voteService.ensureTwitch(element);
        return voteService.getState();
    }

    @POST
    @Path("/round")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    @Operation(
            summary = "Open a new vote round",
            description = "Replaces any previous round. Option ids are assigned a, b, c, ... in order."
    )
    @ApiResponse(responseCode = "200", description = "The new round's state",
            content = @Content(schema = @Schema(implementation = VoteState.class)))
    @ApiResponse(responseCode = "400", description = "Invalid request")
    @ApiResponse(responseCode = "403", description = "Missing or wrong control key")
    public Response openRound(
            final RoundStartRequest request,
            @Parameter(hidden = true)
            @HeaderParam(CONTROL_KEY_HEADER) final String controlKey) {
        if (!isControlAuthorized(controlKey)) {
            return forbidden();
        }
        voteService.ensureTwitch(element);
        try {
            return Response.ok(voteService.openRound(request)).build();
        } catch (IllegalArgumentException e) {
            return badRequest(e.getMessage());
        }
    }

    @POST
    @Path("/close")
    @Produces(MediaType.APPLICATION_JSON)
    @Operation(
            summary = "Close the current round early",
            description = "The final tally remains readable via GET /vote until the next round opens."
    )
    @ApiResponse(responseCode = "200", description = "The closed round's final state",
            content = @Content(schema = @Schema(implementation = VoteState.class)))
    @ApiResponse(responseCode = "403", description = "Missing or wrong control key")
    @ApiResponse(responseCode = "404", description = "No round is open")
    public Response closeRound(
            @Parameter(hidden = true)
            @HeaderParam(CONTROL_KEY_HEADER) final String controlKey) {
        if (!isControlAuthorized(controlKey)) {
            return forbidden();
        }
        try {
            return Response.ok(voteService.closeRound()).build();
        } catch (IllegalStateException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .type(MediaType.APPLICATION_JSON)
                    .entity(Map.of("error", e.getMessage()))
                    .build();
        }
    }

    @POST
    @Path("/inject")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    @Operation(
            summary = "Inject a vote as if it came from chat",
            description = "Testing aid: cast a vote on behalf of an arbitrary voter id. "
                    + "A re-injection for the same voter replaces their previous choice, "
                    + "exactly like a chatter re-typing !vote."
    )
    @ApiResponse(responseCode = "200", description = "The state after the vote",
            content = @Content(schema = @Schema(implementation = VoteState.class)))
    @ApiResponse(responseCode = "400", description = "Missing voterId or optionId")
    @ApiResponse(responseCode = "403", description = "Missing or wrong control key")
    @ApiResponse(responseCode = "409", description = "No open round, or unknown option")
    public Response injectVote(
            final InjectVoteRequest request,
            @Parameter(hidden = true)
            @HeaderParam(CONTROL_KEY_HEADER) final String controlKey) {
        if (!isControlAuthorized(controlKey)) {
            return forbidden();
        }
        if (request == null || request.getVoterId() == null || request.getVoterId().isBlank()
                || request.getOptionId() == null || request.getOptionId().isBlank()) {
            return badRequest("voterId and optionId are required");
        }
        final var accepted = voteService.castVote(request.getVoterId(), request.getOptionId());
        if (!accepted) {
            return Response.status(Response.Status.CONFLICT)
                    .type(MediaType.APPLICATION_JSON)
                    .entity(Map.of("error", "no open round, or unknown option"))
                    .build();
        }
        return Response.ok(voteService.getState()).build();
    }

    private boolean isControlAuthorized(final String provided) {
        final var raw = element.getElementRecord().attributes().getAttribute(TriviaRpgApplication.CONTROL_KEY);
        final var required = raw == null ? "" : raw.toString().trim();
        if (required.isEmpty()) {
            return true;
        }
        if (provided == null) {
            return false;
        }
        return MessageDigest.isEqual(
                provided.getBytes(StandardCharsets.UTF_8),
                required.getBytes(StandardCharsets.UTF_8));
    }

    private static Response forbidden() {
        return Response.status(Response.Status.FORBIDDEN)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of("error", "missing or wrong " + CONTROL_KEY_HEADER + " header"))
                .build();
    }

    private static Response badRequest(final String message) {
        return Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of("error", message))
                .build();
    }

}
