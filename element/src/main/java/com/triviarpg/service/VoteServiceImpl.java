package com.triviarpg.service;

import com.triviarpg.TriviaRpgApplication;
import com.triviarpg.model.RoundStartRequest;
import com.triviarpg.model.VoteOptionState;
import com.triviarpg.model.VoteState;
import com.triviarpg.twitch.TwitchChatClient;
import dev.getelements.elements.sdk.Element;
import dev.getelements.elements.sdk.annotation.ElementServiceExport;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * In-memory vote round state. One round at a time; a new round replaces the old.
 * Re-voting replaces the previous choice. Rounds stay readable (active=false)
 * after closing so the game can fetch the final tally.
 */
@ElementServiceExport(VoteService.class)
public class VoteServiceImpl implements VoteService {

    private static final int MAX_OPTIONS = 10;

    private final Object lock = new Object();
    private final AtomicBoolean twitchStarted = new AtomicBoolean(false);

    private Round round;

    private static final class Option {
        final String id;
        final String text;
        int votes;

        Option(final String id, final String text) {
            this.id = id;
            this.text = text;
        }
    }

    private static final class Round {
        final String questionId;
        final String question;
        final List<Option> options;
        final Map<String, String> voterChoices = new HashMap<>();
        long closesAtEpochMs;
        boolean closed;

        Round(final String questionId, final String question, final List<Option> options,
              final long closesAtEpochMs) {
            this.questionId = questionId;
            this.question = question;
            this.options = options;
            this.closesAtEpochMs = closesAtEpochMs;
        }
    }

    @Override
    public VoteState getState() {
        synchronized (lock) {
            expireIfNeeded();
            return snapshot();
        }
    }

    @Override
    public VoteState openRound(final RoundStartRequest request) {
        synchronized (lock) {
            if (request == null || request.getQuestion() == null || request.getQuestion().isBlank()) {
                throw new IllegalArgumentException("question is required");
            }
            final var texts = request.getOptions() == null ? List.<String>of() : request.getOptions();
            if (texts.size() < 2) {
                throw new IllegalArgumentException("at least 2 options are required");
            }
            if (texts.size() > MAX_OPTIONS) {
                throw new IllegalArgumentException("at most " + MAX_OPTIONS + " options are allowed");
            }
            final long durationSeconds =
                    request.getDurationSeconds() == null ? 0 : request.getDurationSeconds();
            if (durationSeconds < 0) {
                throw new IllegalArgumentException("durationSeconds must be >= 0");
            }

            final var options = new ArrayList<Option>();
            for (int i = 0; i < texts.size(); i++) {
                final var text = texts.get(i) == null ? "" : texts.get(i).trim();
                if (text.isEmpty()) {
                    throw new IllegalArgumentException("options must not be blank");
                }
                options.add(new Option(String.valueOf((char) ('a' + i)), text));
            }

            final long closesAt = durationSeconds > 0
                    ? System.currentTimeMillis() + durationSeconds * 1000
                    : 0;
            round = new Round(UUID.randomUUID().toString(), request.getQuestion().trim(), options, closesAt);
            return snapshot();
        }
    }

    @Override
    public VoteState closeRound() {
        synchronized (lock) {
            expireIfNeeded();
            if (round == null || round.closed) {
                throw new IllegalStateException("no round is open");
            }
            round.closed = true;
            return snapshot();
        }
    }

    @Override
    public boolean castVote(final String voterId, final String optionId) {
        synchronized (lock) {
            expireIfNeeded();
            if (round == null || round.closed) {
                return false;
            }
            if (voterId == null || voterId.isBlank() || optionId == null || optionId.isBlank()) {
                return false;
            }
            final var choice = optionId.trim().toLowerCase(Locale.ROOT);
            Option chosen = null;
            for (final var option : round.options) {
                if (option.id.equals(choice) || option.text.toLowerCase(Locale.ROOT).equals(choice)) {
                    chosen = option;
                    break;
                }
            }
            if (chosen == null) {
                return false;
            }

            final var voter = voterId.trim().toLowerCase(Locale.ROOT);
            final var previous = round.voterChoices.put(voter, chosen.id);
            if (previous == null || !previous.equals(chosen.id)) {
                if (previous != null) {
                    for (final var option : round.options) {
                        if (option.id.equals(previous)) {
                            option.votes = Math.max(0, option.votes - 1);
                            break;
                        }
                    }
                }
                chosen.votes++;
            }
            return true;
        }
    }

    @Override
    public void ensureTwitch(final Element element) {
        if (twitchStarted.get()) {
            return;
        }
        final var raw = element.getElementRecord().attributes().getAttribute(TriviaRpgApplication.TWITCH_CHANNEL);
        final var channel = raw == null ? "" : raw.toString().trim();
        if (channel.isEmpty()) {
            return;
        }
        if (!twitchStarted.compareAndSet(false, true)) {
            return;
        }
        final var client = new TwitchChatClient(channel.toLowerCase(Locale.ROOT),
                (voter, choice) -> castVote(voter, choice));
        element.onClose(el -> client.stop());
        client.start();
    }

    private void expireIfNeeded() {
        if (round != null && !round.closed && round.closesAtEpochMs > 0
                && System.currentTimeMillis() >= round.closesAtEpochMs) {
            round.closed = true;
        }
    }

    private VoteState snapshot() {
        final var state = new VoteState();
        state.setServerTimeEpochMs(System.currentTimeMillis());
        if (round == null) {
            state.setActive(false);
            state.setOptions(new ArrayList<>());
            return state;
        }
        state.setActive(!round.closed);
        state.setQuestionId(round.questionId);
        state.setQuestion(round.question);
        state.setClosesAtEpochMs(round.closesAtEpochMs > 0 ? round.closesAtEpochMs : null);

        long total = 0;
        final var options = new ArrayList<VoteOptionState>();
        for (final var option : round.options) {
            total += option.votes;
            options.add(new VoteOptionState(option.id, option.text, option.votes));
        }
        state.setOptions(options);
        state.setTotalVotes(total);
        return state;
    }

}
