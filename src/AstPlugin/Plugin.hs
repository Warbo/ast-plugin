module AstPlugin.Plugin (plugin) where
import GhcPlugins
import HS2AST.Sexpr

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
               bindsOnlyPass (mapM (printBind dflags)) guts

printBind :: DynFlags -> CoreBind -> CoreM CoreBind
printBind dflags bndr@(NonRec name expr) = do
  printExpr dflags "Non-recursive" (name, expr)
  return bndr
printBind dflags bndr@(Rec bs) = do
  mapM (printExpr dflags "Recursive") bs
  return bndr

printExpr :: DynFlags -> String -> (CoreBndr, Expr CoreBndr) -> CoreM ()
printExpr dflags str (name, expr) = do
  case simpleAst expr of
       Nothing  -> return ()
       Just ast -> putMsgS $ concat [
         "FOUNDAST ",
         showSDoc dflags (ppr name),
         " ",
         show ast]
  return ()
