import Hakyll

cfg :: Configuration
cfg = defaultConfiguration
        { deployCommand = "./publish.sh"
        }

static :: Rules ()
static = do
  match "images/*" $ do
    route idRoute
    compile copyFileCompiler
  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

pages :: Rules ()
pages = match (fromList ["about.md"]) $ do
  route $ setExtension "html"
  compile $ pandocCompiler
    >>= loadAndApplyTemplate "templates/default.html" defaultContext
    >>= relativizeUrls

postTags :: Rules Tags
postTags = buildTags "posts/*" (fromCapture "tags/*.html")

postPages :: Tags -> Rules ()
postPages tags = match "posts/*" $ do
  route $ setExtension "html"
  compile $ pandocCompiler
    >>= saveSnapshot "content"
    >>= loadAndApplyTemplate "templates/post.html" (postCtxWithTags tags)
    >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
    >>= relativizeUrls

tagPages :: Tags -> Rules ()
tagPages tags = tagsRules tags $ \tag ptrn -> do
  let title = "&#35;" ++ tag
  postList ptrn title "templates/tag.html"

index :: Rules ()
index = create ["index.html"] $
  postList "posts/*" "Blog" "templates/index.html"

templates :: Rules ()
templates = match "templates/*" $ compile templateBodyCompiler

postList :: Pattern -> String -> Identifier -> Rules ()
postList ptrn title tmpl = do
  route idRoute
  compile $ do
    posts <- recentFirst =<< loadAll ptrn
    let ctx = listField "posts" postCtx (return posts)
              `mappend` constField "title" title
              `mappend` defaultContext
    makeItem ""
      >>= loadAndApplyTemplate tmpl ctx
      >>= loadAndApplyTemplate "templates/default.html" ctx
      >>= relativizeUrls

postCtx :: Context String
postCtx = dateField "date" "%B %e, %Y"
          `mappend` defaultContext

postCtxWithTags :: Tags -> Context String
postCtxWithTags tags = tagsField "tags" tags
                       `mappend` postCtx

feeds :: Rules ()
feeds = do
  feed renderAtom "feed.atom"
  feed renderRss "feed.rss"
  where
    getPosts = recentFirst =<< loadAllSnapshots "posts/*" "content"
    config = FeedConfiguration
              { feedAuthorEmail = "evgeny@poberezkin.com"
              , feedAuthorName = "Evgeny Poberezkin"
              , feedDescription = "Evgeny Poberezkin's blog."
              , feedRoot = "http://poberezkin.com"
              , feedTitle = "Evgeny Poberezkin"
              }
    ctx = bodyField "description"
          `mappend` postCtx
    feed render name = create [name] $ do
      route idRoute
      compile $ do
        posts <- getPosts
        render config ctx posts

main :: IO ()
main = hakyllWith cfg $ do
  static
  pages
  tags <- postTags
  postPages tags
  tagPages tags
  feeds
  index
  templates
