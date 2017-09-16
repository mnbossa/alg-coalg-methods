#! /usr/bin/env nix-shell
#! nix-shell -i runhaskell -p "haskell.packages.ghc802.ghcWithPackages (pkgs: with pkgs; [turtle aeson wreq])"

{-# LANGUAGE OverloadedStrings #-}

import Prelude hiding (FilePath)
import Turtle hiding (header)
import qualified Data.ByteString as B
import Data.ByteString (ByteString)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8, decodeUtf8)
import Data.Aeson ((.=), object)
import Data.Aeson.Lens (key, _String)
import Control.Lens ((.~), (<&>), set, preview)
import qualified Data.Time as Time
import Network.Wreq (Options, postWith, responseBody, header, param, auth, basicAuth, defaults)

authTokenPwdName = "github-personal-token"
authUser = "paraseba"
projectName = "alg-coalg-methods"
--projectName = "testrelease"
--assetFile = "README.md"
assetFile = "main-results.pdf"

requestOptions :: Token -> Options
requestOptions (Token token) =
  defaults & set auth (Just (basicAuth authUser token))

uploadAsset :: URL -> Token -> Asset -> IO (Maybe Text)
uploadAsset (URL url) token (Asset label path) =
  B.readFile assetPath
    >>= postWith opts (T.unpack url)
    <&> preview (responseBody . key "browser_download_url" . _String)
  where
    assetPath = T.unpack $ format (fp) path
    opts = requestOptions token
      & param "name"  .~ [label]
      & param "label" .~ [label]
      & header "Content-Type" .~ ["application/pdf"]

createRelease :: Token -> ReleaseName -> Asset -> IO (Maybe Text)
createRelease token (RN name) asset = do
  Just uploadUrl <- postWith (requestOptions token) url createBody
                    <&> preview (responseBody . key "upload_url" . _String)
  uploadAsset (sanitizeUrl uploadUrl) token asset

  where
    template = "https://api.github.com/repos/"%s%"/"%s%"/releases"
    url = T.unpack $ format template (decodeUtf8 authUser) projectName
    createBody = object ["tag_name" .= name,
                         "name" .= name,
                         "prerelease" .= True]
    sanitizeUrl url = URL $ T.takeWhile (/= '{') url

releaseName :: IO Text
releaseName =
  T.pack . format <$> date
  where
    dateFormat = ("v" <> Time.iso8601DateFormat Nothing)
    format = Time.formatTime Time.defaultTimeLocale dateFormat

getAuthToken :: IO (ExitCode, Token)
getAuthToken = (Token . encodeUtf8 . T.strip <$>) <$> procStrict "pass" ["show", authTokenPwdName] empty

main = do
  (_, token) <- getAuthToken
  release <- releaseName
  (Just url) <- createRelease token (RN release) (Asset "main-results.pdf" assetFile)
  putStrLn $ T.unpack url

newtype URL = URL Text
newtype Token = Token ByteString
newtype ReleaseName = RN Text
data Asset = Asset Text FilePath
