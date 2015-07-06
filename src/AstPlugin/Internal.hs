{-# LANGUAGE OverloadedStrings #-}
module AstPlugin.Internal where

import Data.Aeson
import Data.Stringable
import GhcPlugins
import HS2AST.Sexpr
import HS2AST.Types

type OPkg  = String
type OMod  = String
type OName = String
data Out   = Out {
    outPackage :: String
  , outModule  :: String
  , outName    :: String
  , outAst     :: AST
  }

instance ToJSON Out where
  toJSON o = object [
      "package" .=       outPackage o
    , "module"  .=       outModule  o
    , "name"    .=       outName    o
    , "ast"     .= show (outAst     o)
    ]

instance Show Out where
  show = toString . encode . toJSON

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
  case simpleAst expr of
       Nothing  -> return ()
       Just ast -> putMsgS . show $ Out {
           outPackage = pprint pkg
         , outModule  = pprint mod
         , outName    = pprint name
         , outAst     = ast
         }
  return ()
  where pprint :: Outputable a => a -> String
        pprint = showSDoc dflags . ppr
