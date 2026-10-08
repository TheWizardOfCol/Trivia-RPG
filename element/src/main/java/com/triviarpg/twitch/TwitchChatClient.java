package com.triviarpg.twitch;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Minimal read-only Twitch chat listener.
 *
 * Connects anonymously (justinfan — no OAuth, no account), joins one channel,
 * and forwards "!vote &lt;choice&gt;" messages to the given handler. Runs a single
 * daemon thread with automatic reconnection.
 */
public class TwitchChatClient {

    private static final Logger LOG = Logger.getLogger(TwitchChatClient.class.getName());

    private static final String HOST = "irc.chat.twitch.tv";
    private static final int[] PORTS = {6697, 443};
    private static final int CONNECT_TIMEOUT_MS = 10_000;
    private static final int READ_TIMEOUT_MS = 300_000;
    private static final long MAX_BACKOFF_MS = 30_000;

    private final String channel;
    private final VoteSink voteSink;

    private volatile boolean running;
    private volatile SocketHolder currentSocket;

    /** Receives (voterId, choice) for each !vote message. */
    public interface VoteSink {
        void onVote(String voterId, String choice);
    }

    private record SocketHolder(SSLSocket socket) {
    }

    public TwitchChatClient(final String channel, final VoteSink voteSink) {
        this.channel = channel;
        this.voteSink = voteSink;
    }

    public void start() {
        running = true;
        final var thread = new Thread(this::runLoop, "twitch-chat-listener");
        thread.setDaemon(true);
        thread.start();
    }

    public void stop() {
        running = false;
        final var holder = currentSocket;
        if (holder != null) {
            try {
                holder.socket().close();
            } catch (IOException ignored) {
                // closing is best-effort
            }
        }
    }

    private void runLoop() {
        var attempt = 0;
        while (running) {
            try {
                connectAndListen();
                attempt = 0;
            } catch (IOException e) {
                if (!running) {
                    break;
                }
                attempt++;
                final var delay = Math.min(MAX_BACKOFF_MS, 2_000L * attempt);
                LOG.log(Level.WARNING,
                        "Twitch chat connection failed (" + e.getMessage() + "); retrying in " + delay + "ms");
                sleep(delay);
            }
        }
        LOG.info("Twitch chat listener stopped");
    }

    private void connectAndListen() throws IOException {
        final SSLSocket socket = connect();
        currentSocket = new SocketHolder(socket);
        try (socket;
             final var writer = new BufferedWriter(
                     new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8));
             final var reader = new BufferedReader(
                     new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))) {

            // Anonymous read-only identity: no password, no account required.
            send(writer, "NICK justinfan" + (10000 + (int) (Math.random() * 90000)));
            send(writer, "JOIN #" + channel);
            LOG.info("Connected to Twitch chat #" + channel);

            String line;
            while (running && (line = reader.readLine()) != null) {
                if (line.startsWith("PING")) {
                    send(writer, "PONG :tmi.twitch.tv");
                    continue;
                }
                handleLine(line);
            }
        } finally {
            currentSocket = null;
        }
    }

    private SSLSocket connect() throws IOException {
        IOException last = null;
        for (final int port : PORTS) {
            try {
                final var socket = (SSLSocket) SSLSocketFactory.getDefault().createSocket();
                socket.connect(new InetSocketAddress(HOST, port), CONNECT_TIMEOUT_MS);
                socket.startHandshake();
                socket.setSoTimeout(READ_TIMEOUT_MS);
                return socket;
            } catch (IOException e) {
                last = e;
            }
        }
        throw last != null ? last : new IOException("unable to connect to " + HOST);
    }

    private void handleLine(final String line) {
        // :user!user@user.tmi.twitch.tv PRIVMSG #channel :message
        final int privmsg = line.indexOf(" PRIVMSG ");
        if (privmsg < 0) {
            return;
        }
        final int bang = line.indexOf('!');
        if (bang <= 1) {
            return;
        }
        final int colon = line.indexOf(" :", privmsg);
        if (colon < 0) {
            return;
        }
        final String user = line.substring(1, bang).toLowerCase(Locale.ROOT);
        final String message = line.substring(colon + 2).trim();
        if (message.length() < 7 || !message.regionMatches(true, 0, "!vote ", 0, 6)) {
            return;
        }
        final String choice = message.substring(6).trim();
        if (!choice.isEmpty()) {
            voteSink.onVote(user, choice);
        }
    }

    private void send(final BufferedWriter writer, final String text) throws IOException {
        writer.write(text);
        writer.write("\r\n");
        writer.flush();
    }

    private void sleep(final long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            running = false;
        }
    }

}
