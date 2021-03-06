module CiaoSyn where

import Data.Char (toLower)
import Data.List (intercalate)
import TyCoRep (Type (..))

newtype CiaoRegtype = CiaoRegtype (CiaoId, [(CiaoId, [CiaoId])])

instance Show CiaoRegtype where
  show (CiaoRegtype (regtypeName, listOfCons)) =
    ":- regtype " ++ (showTypeID regtypeName) ++ "/1.\n" ++ (intercalate "\n" $ map showCons listOfCons)
    where
      showCons =
        ( \(tyConsName, tyConsArgs) ->
            let varIDs = genVarIDs (length tyConsArgs)
             in case length tyConsArgs of
                  0 -> showTypeID regtypeName ++ "(" ++ showTypeID tyConsName ++ ")" ++ "."
                  _ ->
                    showTypeID regtypeName ++ "(" ++ showTypeID tyConsName ++ "(" ++ intercalate ", " varIDs ++ ")) :- "
                      ++ (intercalate ", " $ zipWith (\tyCons varID -> showTypeID tyCons ++ "(" ++ varID ++ ")") tyConsArgs varIDs)
                      ++ ".\n\n"
        )
      genVarIDs = (\len -> map (("X" ++) . show) [1 .. len])

showTypeID :: CiaoId -> String
showTypeID (CiaoId "") = ""
showTypeID (CiaoId str@(x : xs)) =
  case str of
    "Int" -> "num"
    _ -> (toLower x) : xs

newtype CiaoProgram = CiaoProgram [CiaoFunctor]

instance Show CiaoProgram where
  show (CiaoProgram functorList) = intercalate "\n" $ map show functorList

data CiaoFunctor = CiaoFunctor
  { functorName :: CiaoFunctorName,
    functorArity :: Int,
    functorHsType :: ([Type], Type), -- List of argument types, and return type
    functorMetaPred :: CiaoMetaPred,
    functorEntry :: CiaoEntry,
    functorPredDefinition :: CiaoPred,
    functorSubfunctorIds :: [String]
  }

instance Show CiaoFunctor where
  show functor =
    intercalate "\n" $
      [ show (functorMetaPred functor),
        show (functorEntry functor),
        show (functorPredDefinition functor)
      ]

newtype CiaoMetaPred = CiaoMetaPred (String, [Int])

instance Show CiaoMetaPred where
  show (CiaoMetaPred (_, [])) = ""
  show (CiaoMetaPred (predname, arities)) = ":- meta_predicate " ++ predname ++ "(" ++ (intercalate "," (map (\x -> if x == 1 then "?" else "pred(" ++ show x ++ ")") arities)) ++ ",?)."

newtype CiaoEntry = CiaoEntry (String, [String])

instance Show CiaoEntry where
  show (CiaoEntry (_, [])) = ""
  show (CiaoEntry (predname, types)) = ":- entry " ++ predname ++ "/" ++ (show $ (length types) + 1) ++ " : " ++ (intercalate " * " types) ++ " * var."

data CiaoPred
  = CPredC CiaoPredC
  | CPredF CiaoPredF
  | EmptyPred

instance Show CiaoPred where
  show (CPredC predic) = show predic
  show (CPredF predic) = show predic
  show EmptyPred = "" -- EmptyPred is for placeholder purposes

newtype CiaoPredC = CiaoPredC [CiaoClause]

instance Show CiaoPredC where
  show (CiaoPredC []) = ""
  show (CiaoPredC clauseList) = (intercalate "\n" $ map show clauseList) ++ "\n"

newtype CiaoPredF = CiaoPredF [CiaoFunction]

instance Show CiaoPredF where
  show (CiaoPredF []) = ""
  show (CiaoPredF funList) = (intercalate "\n" $ map show funList) ++ "\n"

newtype CiaoBind = CiaoBind (CiaoId, CiaoFunctionBody)

instance Show CiaoBind where
  show (CiaoBind (ciaoid, ciaofunbody)) = show ciaoid ++ " = " ++ show ciaofunbody

data CiaoFunction = CiaoFunction CiaoHead CiaoFunctionBody [CiaoBind]

instance Show CiaoFunction where
  show (CiaoFunction ciaohead fcall bindlist) =
    case fcall of
      CiaoEmptyFB -> ""
      _ -> show ciaohead ++ " := " ++ show fcall ++ (if null bindlist then "" else " :- \n    ") ++ (intercalate ",\n    " $ map show bindlist) ++ "."

data CiaoFunctionBody
  = CiaoFBTerm CiaoFunctorName [CiaoFunctionBody]
  | CiaoFBCall CiaoFunctionCall
  | CiaoFBLit CiaoLiteral
  | CiaoCaseVar CiaoId [(CiaoFunctionBody, CiaoFunctionBody)]
  | CiaoCaseFunCall CiaoFunctionBody [(CiaoFunctionBody, CiaoFunctionBody)]
  | CiaoEmptyFB

instance Show CiaoFunctionBody where
  show (CiaoFBTerm name arglist) =
    case arglist of
      [] -> show name
      _ -> case name of
        (CiaoId ".") -> "[" ++ (intercalate " | " $ map show arglist) ++ "]"
        _ -> show name ++ "(" ++ (intercalate ", " $ map show arglist) ++ ")"
  show (CiaoFBCall funcall) = show funcall
  show (CiaoFBLit lit) = show lit
  show (CiaoCaseVar _ []) = "" -- dummy show, you shouldn't have an empty case
  show (CiaoCaseFunCall _ []) = "" -- dummy show, you shouldn't have an empty case
  show (CiaoCaseVar ciaoid altlist) = "(" ++ (intercalate "\n| " $ zipWith (++) (map (((show ciaoid ++ "=") ++) . (++ " ? ")) (map (show . fst) altlist)) (map (show . snd) altlist)) ++ ")"
  show (CiaoCaseFunCall ciaoid altlist) = "(" ++ (intercalate "\n| " $ zipWith (++) (map (((show ciaoid ++ "=") ++) . (++ " ? ")) (map (show . fst) altlist)) (map (show . snd) altlist)) ++ ")"
  show CiaoEmptyFB = "" -- placeholder body

data CiaoFunctionCall = CiaoFunctionCall CiaoFunctorName [CiaoFunctionBody]

instance Show CiaoFunctionCall where
  show (CiaoFunctionCall name arglist) = "~" ++ (show name) ++ "(" ++ (intercalate ", " $ map show arglist) ++ ")"

data CiaoClause = CiaoClause CiaoHead CiaoBody

instance Show CiaoClause where
  show (CiaoClause ciaohead []) = show ciaohead ++ "."
  show (CiaoClause ciaohead body) = show ciaohead ++ " :- " ++ show body ++ "."

type CiaoHead = CiaoTerm

type CiaoBody = [CiaoTerm]

-- NOTE: No support (yet) for infix variations of operators
data CiaoTerm
  = CiaoTerm CiaoFunctorName [CiaoArg]
  | CiaoTermLit CiaoLiteral
  | CiaoNumber Int
  | CiaoEmptyTerm

instance Show CiaoTerm where
  show (CiaoTerm functor arglist) =
    let functorname = show functor
     in case functorname of
          -- Translates the list cons (:) to Ciao's list cons
          --":" -> ".(" ++ (intercalate "," $ map show arglist) ++ ")"
          _ -> case arglist of
            [] -> functorname
            _ -> case functorname of
              "." -> "[" ++ (intercalate " | " $ map show arglist) ++ "]"
              _ -> functorname ++ "(" ++ (intercalate ", " $ map show arglist) ++ ")"
  show (CiaoTermLit lit) = show lit
  show (CiaoNumber x) = show x
  show CiaoEmptyTerm = "" -- this should only be used with placeholders

type CiaoFunctorName = CiaoId

newtype CiaoId = CiaoId String deriving (Eq)

instance Show CiaoId where
  show (CiaoId str) = str

data CiaoArg
  = CiaoArgId CiaoId
  | CiaoArgTerm CiaoTerm

instance Show CiaoArg where
  show (CiaoArgId ciaoid) = show ciaoid
  show (CiaoArgTerm ciaoterm) = show ciaoterm

data CiaoLiteral = CiaoLitStr String

instance Show CiaoLiteral where
  show (CiaoLitStr str) = str
