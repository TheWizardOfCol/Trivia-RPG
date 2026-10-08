package com.triviarpg.model;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema
public class InjectVoteRequest {

    @NotBlank
    @Schema(description = "Chatter id to vote as (simulates a Twitch vote; used for testing)")
    private String voterId;

    @NotBlank
    @Schema(description = "Option id or exact option text")
    private String optionId;

    public String getVoterId() {
        return voterId;
    }

    public void setVoterId(final String voterId) {
        this.voterId = voterId;
    }

    public String getOptionId() {
        return optionId;
    }

    public void setOptionId(final String optionId) {
        this.optionId = optionId;
    }

}
