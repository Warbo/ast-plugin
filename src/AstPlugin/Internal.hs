{-# LANGUAGE OverloadedStrings #-}
module AstPlugin.Internal where

import           Data.Aeson
import           Data.Stringable
import qualified Data.Text       as T
import           GhcPlugins
import           HS2AST.Sexpr
import           HS2AST.Types

plugin :: Plugin
plugin = defaultPlugin {
    installCoreToDos = install
  }

install :: [CommandLineOption] -> [CoreToDo] -> CoreM [CoreToDo]
install _ todo = do
  reinitializeGlobals
  return (CoreDoPluginPass "AST Plugin" pass : todo)

pass :: ModGuts -> CoreM ModGuts
pass guts = do dflags <- getDynFlags
               let mod     = mg_module guts
                   pkg     = modulePackageKey mod
                   modName = moduleName       mod
                   printer = printBind dflags pkg modName
               bindsOnlyPass (mapM printer) guts

printBind :: DynFlags -> PackageKey -> ModuleName -> CoreBind -> CoreM CoreBind
printBind dflags pkg mod bndr = do
  case bndr of
       NonRec name expr ->       printer (name, expr)
       Rec bs           -> mapM_ printer  bs
  return bndr
  where printer = printExpr dflags pkg mod

printExpr :: DynFlags
          -> PackageKey
          -> ModuleName
          -> (CoreBndr, Expr CoreBndr)
          -> CoreM ()
printExpr dflags pkg mod (name, expr) = do
  putMsgS . show $ Out {
      outPackage = if isMain then "main" else T.pack (pprint pkg)
    , outModule  = T.pack (pprint mod)
    , outName    = T.pack (pprint name)
    , outAst     = toSexp (pkgDb dflags) expr
    }
  return ()
  where pprint :: Outputable a => a -> String
        pprint = showSDoc dflags . ppr
        isMain = packageKeyString pkg == "main"

pkgDb :: DynFlags -> PackageDb
pkgDb dflags = fmap (PackageName . mkFastString) . packageKeyPackageIdString dflags
