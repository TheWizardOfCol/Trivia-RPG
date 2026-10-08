package com.triviarpg.model;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema
public class VoteOptionState {

    @Schema(description = "Short option id chatters type after !vote (a, b, c, ...)")
    private String id;

    @Schema(description = "Human-readable option text")
    private String text;

    @Schema(description = "Current vote count for this option")
    private int votes;

    public VoteOptionState() {
    }

    public VoteOptionState(final String id, final String text, final int votes) {
        this.id = id;
        this.text = text;
        this.votes = votes;
    }

    public String getId() {
        return id;
    }

    public void setId(final String id) {
        this.id = id;
    }

    public String getText() {
        return text;
    }

    public void setText(final String text) {
        this.text = text;
    }

    public int getVotes() {
        return votes;
    }

    public void setVotes(final int votes) {
        this.votes = votes;
    }

}
