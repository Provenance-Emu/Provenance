//
//  Service_TheGamesDB.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 12/30/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

let API_KEY = "fe49d95136b2d03e2ae86dead3650af597928885fe4aa573d9dba805d66027a7"

let g_getGameUrl = "https://api.thegamesdb.net/v1/Games/GamesByGameID?apikey=\(API_KEY)&fields=overview,uids&include=boxart&id=%d"
let g_getGamesByUIDUrl = "https://api.thegamesdb.net/v1/Games/ByGameUniqueID?apikey=\(API_KEY)&filter%5Bplatform%5D=11&fields=overview,uids&include=boxart"
let g_getGamesListUrl = "https://api.thegamesdb.net/v1.1/Games/ByGameName?apikey=\(API_KEY)&fields=overview,uids&filter%5Bplatform%5D=%s&include=boxart&name=%s"

class TheGamesDBService {
    func getGames(serials: [String]) {
        /*
         std::ostringstream stream;
         std::copy(serials.begin(), serials.end(), std::ostream_iterator<std::string>(stream, ","));
         auto str_games_id = stream.str();

         GamesList gamesList;

         auto url = std::string(g_getGamesByUIDUrl);
         url += "&uid=";
         url += str_games_id;
         while(!url.empty())
         {
             auto requestResult =
                 [&]() {
                     auto client = Framework::Http::CreateHttpClient();
                     client->SetUrl(url);
                     return client->SendRequest();
                 }();

             url.clear();
             if(requestResult.statusCode == Framework::Http::HTTP_STATUS_CODE::OK)
             {
                 auto json_ret = requestResult.data.ReadString();
                 auto parsed_json = nlohmann::json::parse(json_ret);

                 auto games = PopulateGameList(parsed_json);
                 gamesList.insert(gamesList.end(), games.begin(), games.end());

                 if(!parsed_json["pages"]["next"].empty())
                 {
                     url = parsed_json["pages"]["next"].get<std::string>();
                 }
             }
         }
         return gamesList;
         */
    }
    func getGame(id: String) {
        /*
         auto url = string_format(g_getGameUrl, id);
         auto requestResult =
             [&]() {
                 auto client = Framework::Http::CreateHttpClient();
                 client->SetUrl(url);
                 return client->SendRequest();
             }();

         if(requestResult.statusCode != Framework::Http::HTTP_STATUS_CODE::OK)
         {
             throw std::runtime_error("Failed to get game.");
         }

         auto json_ret = requestResult.data.ReadString();
         auto parsed_json = nlohmann::json::parse(json_ret);

         auto gamesList = PopulateGameList(parsed_json);
         if(gamesList.empty())
         {
             throw std::runtime_error("Failed to get game.");
         }
         return gamesList.at(0);
         */
    }
    
    func getGamesList(platformID: String, name: String) {
        /*
         auto encodedName = Framework::UrlEncode(name);

         auto url = string_format(g_getGamesListUrl, platformID.c_str(), encodedName.c_str());
         auto requestResult =
             [&]() {
                 auto client = Framework::Http::CreateHttpClient();
                 client->SetUrl(url);
                 return client->SendRequest();
             }();

         if(requestResult.statusCode != Framework::Http::HTTP_STATUS_CODE::OK)
         {
             throw std::runtime_error("Failed to get games list.");
         }

         auto json_ret = requestResult.data.ReadString();
         auto parsed_json = nlohmann::json::parse(json_ret);

         auto gamesList = PopulateGameList(parsed_json);
         if(gamesList.empty())
         {
             throw std::runtime_error("Failed to get game.");
         }

         return gamesList;
         */
    }
    
    func populateGamesList(json: String) {
        /*
         GamesList list;

         if(parsed_json["data"]["count"].get<int>() == 0)
         {
             return list;
         }

         std::string image_base = "";
         auto includes = parsed_json["include"];
         if(!includes.empty())
         {
             image_base = includes["boxart"]["base_url"]["medium"].get<std::string>();
         }

         auto games = parsed_json["data"]["games"].get<std::vector<nlohmann::json>>();
         for(auto game : games)
         {
             int game_id = game["id"].get<int>();
             TheGamesDb::Game meta;
             meta.id = game_id;
             if(!game["overview"].empty())
             {
                 meta.overview = game["overview"].get<std::string>();
             }
             if(!game["uids"].empty())
             {
                 auto uids = game["uids"].get<std::vector<nlohmann::json>>();
                 for(auto item : uids)
                 {
                     meta.discIds.push_back(item["uid"].get<std::string>());
                 }
             }
             meta.title = game["game_title"].get<std::string>();
             meta.baseImgUrl = image_base;
             if(!includes.empty())
             {
                 auto boxarts = includes["boxart"]["data"];
                 if(!boxarts.empty())
                 {
                     auto str_id = std::to_string(game_id);
                     auto games_cover_meta = boxarts[str_id.c_str()];
                     if(!games_cover_meta.empty())
                     {
                         for(auto& game_cover : games_cover_meta)
                         {
                             meta.boxArtUrl = game_cover["filename"].get<std::string>().c_str();
                             if(game_cover["side"].get<std::string>() == "front")
                             {
                                 break;
                             }
                         }
                     }
                 }
             }
             list.push_back(meta);
         }
         return list;
         */
    }
}
