package com.triviarpg.guice;

import com.google.inject.PrivateModule;
import com.google.inject.Singleton;
import com.triviarpg.service.VoteService;
import com.triviarpg.service.VoteServiceImpl;

public class TriviaRpgModule extends PrivateModule {

    @Override
    protected void configure() {

        bind(VoteService.class).to(VoteServiceImpl.class).in(Singleton.class);

        expose(VoteService.class);
    }
}
