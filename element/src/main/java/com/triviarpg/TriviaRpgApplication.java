package com.triviarpg;

import com.triviarpg.rest.VoteEndpoint;
import dev.getelements.elements.sdk.annotation.ElementDefaultAttribute;
import dev.getelements.elements.sdk.annotation.ElementServiceExport;
import dev.getelements.elements.sdk.annotation.ElementServiceImplementation;
import jakarta.ws.rs.core.Application;

import java.util.Set;

@ElementServiceImplementation
@ElementServiceExport(Application.class)
public class TriviaRpgApplication extends Application {

    /**
     * Platform auth filter. Off by default so the public vote poll needs no login;
     * flip to "true" once the game also talks to authenticated platform APIs.
     */
    @ElementDefaultAttribute("false")
    public static final String AUTH_ENABLED = "dev.getelements.elements.auth.enabled";

    /** Mount root of this Element's REST endpoints → /trivia-rpg/vote, ... */
    @ElementDefaultAttribute("/trivia-rpg")
    public static final String RS_ROOT = "dev.getelements.elements.element.rs.root";

    /** WebSocket base path (unused so far; reserved for push updates later). */
    @ElementDefaultAttribute("/trivia-rpg/ws")
    public static final String WS_ROOT = "dev.getelements.elements.element.ws.root";

    /**
     * Twitch channel to join for chat voting (without #). Empty = chat listener
     * stays off and only POST /vote/inject can cast votes.
     */
    @ElementDefaultAttribute("")
    public static final String TWITCH_CHANNEL = "trivia.twitch.channel";

    /**
     * Key required on control endpoints (round/close/inject) as X-Trivia-Key.
     * Empty = control endpoints are open (local development only).
     */
    @ElementDefaultAttribute("")
    public static final String CONTROL_KEY = "trivia.control.key";

    public static final String OPENAPI_TAG = "Trivia-RPG";

    @Override
    public Set<Class<?>> getClasses() {
        return Set.of(
                VoteEndpoint.class,
                OpenAPISecurityConfig.class
        );
    }

}
