module Main (main) where

import Control.Monad.State hiding (state)
import Foreign.Marshal.Utils
import Foreign.Ptr
import GHC.Word
import Graphics.UI.SDL.Types
import Shared.Drawing
import Shared.Input
import Shared.Lifecycle
import Shared.Assets
import Shared.Polling
import Shared.Utilities
import Shared.State
import qualified Graphics.UI.SDL as SDL
import qualified Graphics.UI.SDL.Image as Image


title :: String
title = "lesson13"

size :: ScreenSize
size = (640, 480)

inWindow :: (SDL.Window -> IO ()) -> IO ()
inWindow = withSDL . withWindow title size

fullWindow :: SDL.Rect
fullWindow = SDL.Rect {
    rectX = 0,
    rectY = 0,
    rectW = fst size,
    rectH = snd size }

initialState :: World
initialState = World { gameover = False, alpha = 0 }


main :: IO ()
main = inWindow $ \window -> Image.withImgInit [Image.InitPNG] $ do
    _ <- setHint "SDL_RENDER_SCALE_QUALITY" "1" >>= logWarning
    renderer <- createRenderer window (-1) [SDL.SDL_RENDERER_ACCELERATED] >>= either throwSDLError return
    withAssets renderer ["./assets/fadein.png", "./assets/fadeout.png"] $ \assets -> do
        let inputSource = pollEvent `into` updateState
        let pollDraw = inputSource ~>~ drawWorld renderer assets
        runStateT (repeatUntilComplete pollDraw) initialState
    SDL.destroyRenderer renderer


data ColourProperty = Alpha
data World = World { gameover :: Bool, alpha :: Word8 }

drawWorld :: SDL.Renderer -> [Asset] -> World -> IO ()
drawWorld renderer assets (World False alphaValue) = withBlankScreen renderer $ do
    let (background, _, _) = head assets
    let (foreground, _, _) = assets !! 1
    _ <- SDL.setTextureAlphaMod foreground alphaValue
    _ <- with fullWindow $ SDL.renderCopy renderer background nullPtr
    _ <- with fullWindow $ SDL.renderCopy renderer foreground nullPtr
    return ()
drawWorld _ _ _ = return ()

updateState :: Input -> World -> World
updateState (Just (SDL.KeyboardEvent evtType _ _ _ _ keysym)) state = if evtType == SDL.SDL_KEYDOWN then modifyState state keysym else state
updateState (Just (SDL.QuitEvent _ _)) state = state { gameover = True }
updateState _ state = state

modifyState :: World -> SDL.Keysym -> World
modifyState state keysym = case getKey keysym of
    W -> state `increase` Alpha
    S -> state `decrease` Alpha
    _ -> state

increase :: World -> ColourProperty -> World
increase state Alpha = state { alpha = alpha state + 16 }

decrease :: World -> ColourProperty -> World
decrease state Alpha = state { alpha = alpha state - 16 }

repeatUntilComplete :: (Monad m) => m World -> m ()
repeatUntilComplete game = do
    state <- game
    unless (gameover state) $ repeatUntilComplete game

