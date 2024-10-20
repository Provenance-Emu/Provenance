

CREATE TABLE "REGIONS" (
"regionID" INTEGER PRIMARY KEY AUTOINCREMENT,
"regionName" TEXT
);


CREATE TABLE "RELEASES" (
"releaseID" INTEGER PRIMARY KEY AUTOINCREMENT,
"romID" INTEGER,
"releaseTitleName" TEXT,
"regionLocalizedID" INTEGER,
"TEMPregionLocalizedName" TEXT,
"TEMPsystemShortName" TEXT,
"TEMPsystemName" TEXT,
"releaseCoverFront" TEXT,
"releaseCoverBack" TEXT,
"releaseCoverCart" TEXT,
"releaseCoverDisc" TEXT,
"releaseDescription" TEXT,
"releaseDeveloper" TEXT,
"releasePublisher" TEXT,
"releaseGenre" TEXT,
"releaseDate" TEXT,
"releaseReferenceURL" TEXT,
"releaseReferenceImageURL" TEXT
);


CREATE TABLE "ROMs" (
"romID" INTEGER PRIMARY KEY AUTOINCREMENT,
"systemID" INTEGER,
"regionID" INTEGER,
"romHashCRC" TEXT,
"romHashMD5" TEXT,
"romHashSHA1" TEXT,
"romSize" INTEGER,
"romFileName" TEXT,
"romExtensionlessFileName" TEXT,
"romParent" TEXT,
"romSerial" TEXT,
"romHeader" TEXT,
"romLanguage" TEXT,
"TEMPromRegion" TEXT,
"romDumpSource" TEXT
);


CREATE TABLE "SYSTEMS" (
"systemID" INTEGER PRIMARY KEY AUTOINCREMENT,
"systemName" TEXT,
"systemShortName" TEXT,
"systemHeaderSizeBytes" INTEGER,
"systemHashless" INTEGER,
"systemHeader" INTEGER,
"systemSerial" TEXT,
"systemOEID" TEXT
);
