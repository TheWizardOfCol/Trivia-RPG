package com.triviarpg.service;

import com.triviarpg.model.RoundStartRequest;
import com.triviarpg.model.VoteState;
import dev.getelements.elements.sdk.Element;

/**
 * Owns the current chat-vote round and the Twitch chat connection that feeds it.
 */
public interface VoteService {

    /**
     * Snapshot of the current (or most recent) round. Expiry is applied lazily here.
     */
    VoteState getState();

    /**
     * Opens a new round, replacing any previous one.
     *
     * @throws IllegalArgumentException if the request is invalid
     */
    VoteState openRound(RoundStartRequest request);

    /**
     * Closes the current round early, preserving the final tally.
     *
     * @throws IllegalStateException if no round is open
     */
    VoteState closeRound();

    /**
     * Records (or replaces) a vote from the given voter.
     *
     * @return true if the vote was accepted
     */
    boolean castVote(String voterId, String optionId);

    /**
     * Starts the Twitch chat listener if configured and not already running.
     * Safe to call on every request. Also registers cleanup on element close.
     */
    void ensureTwitch(Element element);

}
