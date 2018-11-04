package com.reicast.emulator.cloud;

import com.dropbox.core.DbxRequestConfig;
import com.dropbox.core.http.StandardHttpRequestor;
import com.dropbox.core.v2.DbxClientV2;

/**
 * Singleton instance of {@link DbxClientV2} and friends
 */
public class DbxClientFactory {

    private static DbxClientV2 sDbxClient;

    public static void init(String accessToken) {
        if (sDbxClient == null) {
            StandardHttpRequestor requestor = new StandardHttpRequestor(
                    StandardHttpRequestor.Config.DEFAULT_INSTANCE);
            DbxRequestConfig requestConfig = DbxRequestConfig
                    .newBuilder("ReicastCloud")
                    .withHttpRequestor(requestor).build();

            sDbxClient = new DbxClientV2(requestConfig, accessToken);
        }
    }

    public static DbxClientV2 getClient() {
        if (sDbxClient == null) {
            throw new IllegalStateException("Client not initialized.");
        }
        return sDbxClient;
    }
}
