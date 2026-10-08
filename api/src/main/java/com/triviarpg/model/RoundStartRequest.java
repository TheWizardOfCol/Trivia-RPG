package com.triviarpg.model;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.ArrayList;
import java.util.List;

@Schema
public class RoundStartRequest {

    @NotBlank
    @Schema(description = "The question chatters are voting on", example = "Which door do we take?")
    private String question;

    @NotNull
    @Schema(description = "2-10 option texts; ids are assigned a, b, c, ... in order")
    private List<String> options = new ArrayList<>();

    @Schema(description = "Optional auto-close after this many seconds (omit or 0 for manual close)")
    private Long durationSeconds;

    public String getQuestion() {
        return question;
    }

    public void setQuestion(final String question) {
        this.question = question;
    }

    public List<String> getOptions() {
        return options;
    }

    public void setOptions(final List<String> options) {
        this.options = options;
    }

    public Long getDurationSeconds() {
        return durationSeconds;
    }

    public void setDurationSeconds(final Long durationSeconds) {
        this.durationSeconds = durationSeconds;
    }

}
