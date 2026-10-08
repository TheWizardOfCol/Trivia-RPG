package com.triviarpg.model;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.ArrayList;
import java.util.List;

@Schema
public class VoteState {

    @Schema(description = "True while chatters can still vote")
    private boolean active;

    @Schema(description = "Unique id of the current/last round; changes whenever a new round opens")
    private String questionId;

    @Schema(description = "The question being voted on")
    private String question;

    @Schema(description = "Options with live tallies")
    private List<VoteOptionState> options = new ArrayList<>();

    @Schema(description = "Sum of votes across all options")
    private long totalVotes;

    @Schema(description = "Epoch millis when the round auto-closes; null or 0 means no expiry")
    private Long closesAtEpochMs;

    @Schema(description = "Server time at which this snapshot was taken (epoch millis)")
    private long serverTimeEpochMs;

    public boolean isActive() {
        return active;
    }

    public void setActive(final boolean active) {
        this.active = active;
    }

    public String getQuestionId() {
        return questionId;
    }

    public void setQuestionId(final String questionId) {
        this.questionId = questionId;
    }

    public String getQuestion() {
        return question;
    }

    public void setQuestion(final String question) {
        this.question = question;
    }

    public List<VoteOptionState> getOptions() {
        return options;
    }

    public void setOptions(final List<VoteOptionState> options) {
        this.options = options;
    }

    public long getTotalVotes() {
        return totalVotes;
    }

    public void setTotalVotes(final long totalVotes) {
        this.totalVotes = totalVotes;
    }

    public Long getClosesAtEpochMs() {
        return closesAtEpochMs;
    }

    public void setClosesAtEpochMs(final Long closesAtEpochMs) {
        this.closesAtEpochMs = closesAtEpochMs;
    }

    public long getServerTimeEpochMs() {
        return serverTimeEpochMs;
    }

    public void setServerTimeEpochMs(final long serverTimeEpochMs) {
        this.serverTimeEpochMs = serverTimeEpochMs;
    }

}
