module Main where

import AstPlugin.Internal
import CoreMonad
import Test.QuickCheck.Monadic
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.QuickCheck

main = defaultMain $ testGroup "Impure tests" [
    testProperty "" astsHavePackageName
  ]

astsHavePackageName (Blind d) s (Blind bs) env rs u m (Blind p) =
  monadic (runCoreM env rs u m p) $ do
    run $ printExpr d s bs
