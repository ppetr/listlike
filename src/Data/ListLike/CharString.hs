{-# LANGUAGE MultiParamTypeClasses            
            ,FlexibleInstances
            ,TypeSynonymInstances #-}


{-
Copyright (C) 2007 John Goerzen <jgoerzen@complete.org>

All rights reserved.

For license and copyright information, see the file COPYRIGHT

-}

{- |
   Module     : Data.ListLike.CharString
   Copyright  : Copyright (C) 2007 John Goerzen
   License    : BSD3

   Maintainer : John Lato <jwlato@gmail.com>
   Stability  : provisional
   Portability: portable

Newtype wrapper for ByteString to enable a Char-based interface
Re-exported by "Data.ListLike".

Written by John Lato, jwlato\@gmail.com
-}

module Data.ListLike.CharString (
  CharString (..)
 ,CharStringLazy (..)
)

where

import Prelude hiding (length, head, last, null, tail, map, filter, concat, 
                       any, lookup, init, all, foldl, foldr, foldl1, foldr1,
                       maximum, minimum, iterate, span, break, takeWhile,
                       dropWhile, reverse, zip, zipWith, sequence,
                       sequence_, mapM, mapM_, concatMap, and, or, sum,
                       product, repeat, replicate, cycle, take, drop,
                       splitAt, elem, notElem, unzip, lines, words,
                       unlines, unwords)
import qualified Data.Foldable as F
import           Data.ListLike.Base
import qualified Data.ListLike.Base as Base
import           Data.ListLike.String
import           Data.ListLike.IO
import           Data.ListLike.FoldableLL
import           Data.ListLike.UnfoldableLL
import           Data.ListLike.TraversableLL
import           Data.Int
import           Data.Monoid
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified System.IO as IO
import           Data.Word
import           Control.Arrow

--------------------------------------------------
-- ByteString

-- | Newtype wrapper around Data.ByteString.Char8.ByteString,
--   this allows for ListLike instances with Char elements.
newtype CharString = CS { unCS :: BS.ByteString }
  deriving (Read, Show, Eq, Ord)

instance Monoid CharString where
  mempty = CS mempty
  mappend l r = CS $ mappend (unCS l) (unCS r)

instance FoldableLL CharString Char where
    foldl f i0  ls = BS.foldl f i0 (unCS ls)
    foldl' f i0 ls = BS.foldl' f i0 (unCS ls)
    foldl1 f    ls = BS.foldl1 f (unCS ls)
    foldr f i0  ls = BS.foldr f i0 (unCS ls)
    foldr1 f    ls = BS.foldr1 f (unCS ls)

    head = BS.head . unCS
    last = BS.last . unCS
    null = BS.null . unCS
    length = BS.length . unCS
    genericLength = fromIntegral . BS.length . unCS
    find p = BS.find p . unCS
    index l i = BS.index (unCS l) (fromIntegral i)

    concat = CS . BS.concat . map unCS . toList
    --concatMap = BS.concatMap
    rigidConcatMap f = CS . BS.concatMap (unCS . f) . unCS
    any p = BS.any p . unCS
    all p = BS.all p . unCS
    maximum = BS.maximum . unCS
    minimum = BS.minimum . unCS
    elem x = BS.elem x . unCS
    notElem x = BS.notElem x . unCS
    toList = BS.unpack . unCS
    toListN (CS s) = (Just (BS.length s), BS.unpack s)

    elemIndex i = BS.elemIndex i  . unCS
    --elemIndices x = fromList . L.map fromIntegral . BS.elemIndices x
    findIndex f = BS.findIndex f . unCS
    --findIndices x = fromList . L.map fromIntegral . BS.findIndices x
    isPrefixOf p f = BS.isPrefixOf (unCS p) (unCS f)

instance TraversableLL CharString Char where
    rigidMap f = CS . BS.map f . unCS
    rigidTraverse = traverse

instance UnfoldableLL CharString Char where
    unfoldr f s = CS $ BS.unfoldr f s
    unfoldrN n f s = CS $ fst $ BS.unfoldrN n f s
    empty = CS BS.empty
    singleton = CS . BS.singleton
    --replicate i = CS . BS.replicate (fromIntegral i)
    fromList = CS . BS.pack
    fromListLike = fromList . toList
    --genericReplicate i = CS . BS.replicate (fromIntegral i)

instance ListLike CharString Char where
    cons x l = CS (BS.cons x (unCS l))
    snoc l x = CS (BS.snoc (unCS l) x)
    append l r = CS $ BS.append (unCS l) (unCS r)
    tail = CS . BS.tail . unCS
    init = CS . BS.init . unCS
    -- map = BS.map
    reverse = CS . BS.reverse . unCS
    --intersperse = BS.intersperse
    take i = CS . BS.take (fromIntegral i) . unCS
    drop i = CS . BS.drop (fromIntegral i) . unCS
    splitAt i = (CS *** CS) . BS.splitAt (fromIntegral i) . unCS
    takeWhile p = CS . BS.takeWhile p . unCS
    dropWhile p = CS . BS.dropWhile p . unCS
    span p  = (CS *** CS) . BS.span p . unCS
    break p = (CS *** CS) . BS.break p . unCS
    group = fromList . map CS . BS.group . unCS
    inits = fromList . map CS . BS.inits . unCS
    tails = fromList . map CS . BS.tails . unCS
    --isSuffixOf = BS.isSuffixOf
    --isInfixOf = BS.isInfixOf
    filter p = CS . BS.filter p . unCS
    --partition = BS.partition
    --sequence = BS.sequence
    --mapM = BS.mapM
    --mapM_ = BS.mapM_
    --nub = BS.nub
    --delete = BS.delete
    --deleteFirsts = BS.deleteFirsts
    --union = BS.union
    --intersect = BS.intersect
    --sort = BS.sort
    --insert = BS.insert
    --nubBy = BS.nubBy
    --deleteBy = BS.deleteBy
    --deleteFirstsBy = BS.deleteFirstsBy
    --unionBy = BS.unionBy
    --intersectBy = BS.intersectBy
    -- BS.groupBy is broken. groupBy f = fromList . BS.groupBy f
    -- the below works on ghc but generates a type error on hugs
    -- groupBy func = map fromList . L.groupBy func . toList
    --sortBy = BS.sortBy
    --insertBy = BS.insertBy
    genericTake i = CS . BS.take (fromIntegral i) . unCS
    genericDrop i = CS . BS.drop (fromIntegral i) . unCS
    genericSplitAt i = (CS *** CS) . BS.splitAt (fromIntegral i) . unCS

instance ListLikeIO CharString Char where
    hGetLine h = fmap CS $ BS.hGetLine h
    hGetContents = fmap CS . BS.hGetContents
    hGet h n = fmap CS $ BS.hGet h n
    hGetNonBlocking h n = fmap CS $ BS.hGetNonBlocking h n
    hPutStr h = BS.hPut h . unCS
    --hPutStrLn = BS.hPutStrLn
    getLine = fmap CS BS.getLine
    getContents = fmap CS BS.getContents
    putStr = BS.putStr . unCS
    putStrLn = BS.putStrLn . unCS
    interact f = BS.interact (unCS . f . CS)
    readFile = fmap CS . BS.readFile
    writeFile fp = BS.writeFile fp . unCS
    appendFile fp = BS.appendFile fp . unCS

instance StringLike CharString where
    toString = BS.unpack . unCS
    fromString = CS . BS.pack

--------------------------------------------------
-- ByteString.Lazy

-- | Newtype wrapper around Data.ByteString.Lazy.Char8.ByteString,
--   this allows for ListLike instances with Char elements.
newtype CharStringLazy = CSL { unCSL :: BSL.ByteString }
  deriving (Read, Show, Eq, Ord)

instance Monoid CharStringLazy where
  mempty = CSL mempty
  mappend l r = CSL $ mappend (unCSL l) (unCSL r)

instance FoldableLL CharStringLazy Char where
    foldl f i0  ls = BSL.foldl f i0 (unCSL ls)
    foldl' f i0 ls = BSL.foldl' f i0 (unCSL ls)
    foldl1 f    ls = BSL.foldl1 f (unCSL ls)
    foldr f i0  ls = BSL.foldr f i0 (unCSL ls)
    foldr1 f    ls = BSL.foldr1 f (unCSL ls)

    head = BSL.head . unCSL
    last = BSL.last . unCSL
    null = BSL.null . unCSL
    length = fromIntegral . BSL.length . unCSL
    genericLength = fromIntegral . BSL.length . unCSL
    find p = BSL.find p . unCSL
    index l i = BSL.index (unCSL l) (fromIntegral i)

    elemIndex i = mi64toi . BSL.elemIndex i  . unCSL
    --elemIndices x = fromList . L.map fromIntegral . BSL.elemIndices x
    findIndex f = mi64toi . BSL.findIndex f . unCSL
    --findIndices x = fromList . L.map fromIntegral . BSL.findIndices x
    isPrefixOf p f = BSL.isPrefixOf (unCSL p) (unCSL f)

mi64toi :: Maybe Int64 -> Maybe Int
mi64toi Nothing = Nothing
mi64toi (Just x) = Just (fromIntegral x)

instance TraversableLL CharStringLazy Char where
    rigidMap f = CSL . BSL.map f . unCSL
    rigidTraverse = traverse

instance UnfoldableLL CharStringLazy Char where
    unfoldr f s = CSL $ BSL.unfoldr f s
    empty = CSL BSL.empty
    singleton = CSL . BSL.singleton
    --replicate i = CS . BS.replicate (fromIntegral i)
    fromList = CSL . BSL.pack
    fromListLike = fromList . toList
    --genericReplicate i = CS . BS.replicate (fromIntegral i)

instance ListLike CharStringLazy Char where
    cons x l = CSL (BSL.cons x (unCSL l))
    snoc l x = CSL (BSL.snoc (unCSL l) x)
    append l r = CSL $ BSL.append (unCSL l) (unCSL r)
    tail = CSL . BSL.tail . unCSL
    init = CSL . BSL.init . unCSL
    -- map = BSL.map
    reverse = CSL . BSL.reverse . unCSL
    --intersperse = BSL.intersperse
    take i = CSL . BSL.take (fromIntegral i) . unCSL
    drop i = CSL . BSL.drop (fromIntegral i) . unCSL
    splitAt i = (CSL *** CSL) . BSL.splitAt (fromIntegral i) . unCSL
    takeWhile p = CSL . BSL.takeWhile p . unCSL
    dropWhile p = CSL . BSL.dropWhile p . unCSL
    span p  = (CSL *** CSL) . BSL.span p . unCSL
    break p = (CSL *** CSL) . BSL.break p . unCSL
    group = fromList . map CSL . BSL.group . unCSL
    inits = fromList . map CSL . BSL.inits . unCSL
    tails = fromList . map CSL . BSL.tails . unCSL
    --isSuffixOf = BSL.isSuffixOf
    --isInfixOf = BSL.isInfixOf
    filter p = CSL . BSL.filter p . unCSL
    --partition = BSL.partition
    --sequence = BSL.sequence
    --mapM = BSL.mapM
    --mapM_ = BSL.mapM_
    --nub = BSL.nub
    --delete = BSL.delete
    --deleteFirsts = BSL.deleteFirsts
    --union = BSL.union
    --intersect = BSL.intersect
    --sort = BSL.sort
    --insert = BSL.insert
    --nubBy = BSL.nubBy
    --deleteBy = BSL.deleteBy
    --deleteFirstsBy = BSL.deleteFirstsBy
    --unionBy = BSL.unionBy
    --intersectBy = BSL.intersectBy
    -- BSL.groupBy is broken. groupBy f = fromList . BSL.groupBy f
    -- the below works on ghc but generates a type error on hugs
    -- groupBy func = map fromList . L.groupBy func . toList
    --sortBy = BSL.sortBy
    --insertBy = BSL.insertBy
    genericTake i = CSL . BSL.take (fromIntegral i) . unCSL
    genericDrop i = CSL . BSL.drop (fromIntegral i) . unCSL
    genericSplitAt i = (CSL *** CSL) . BSL.splitAt (fromIntegral i) . unCSL

strict2lazy :: BS.ByteString -> CharStringLazy
strict2lazy b = CSL $ BSL.fromChunks [b]

instance ListLikeIO CharStringLazy Char where
    hGetLine h = fmap strict2lazy $ BS.hGetLine h
    hGetContents = fmap CSL . BSL.hGetContents
    hGet h n = fmap CSL $ BSL.hGet h n
    hGetNonBlocking h n = fmap CSL $ BSL.hGetNonBlocking h n
    hPutStr h = BSL.hPut h . unCSL
    --hPutStrLn = BSL.hPutStrLn
    getLine = fmap strict2lazy BS.getLine
    getContents = fmap CSL BSL.getContents
    putStr = BSL.putStr . unCSL
    putStrLn = BSL.putStrLn . unCSL
    interact f = BSL.interact (unCSL . f . CSL)
    readFile = fmap CSL . BSL.readFile
    writeFile fp = BSL.writeFile fp . unCSL
    appendFile fp = BSL.appendFile fp . unCSL

instance StringLike CharStringLazy where
    toString = BSL.unpack . unCSL
    fromString = CSL . BSL.pack
