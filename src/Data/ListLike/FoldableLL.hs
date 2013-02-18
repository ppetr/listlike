{-# LANGUAGE MultiParamTypeClasses
            ,FunctionalDependencies
            ,FlexibleInstances #-}

{-
Copyright (C) 2007 John Goerzen <jgoerzen@complete.org>

All rights reserved.

For license and copyright information, see the file COPYRIGHT
-}

{- |
   Module     : Data.ListLike.FoldableLL
   Copyright  : Copyright (C) 2007 John Goerzen
   License    : BSD3

   Maintainer : John Lato <jwlato@gmail.com>
   Stability  : provisional
   Portability: portable

Generic tools for data structures that can be folded.

Written by John Goerzen, jgoerzen\@complete.org

-}
module Data.ListLike.FoldableLL 
    (-- * FoldableLL Class
     FoldableLL(..),
     -- * Utilities
     fold, foldMap, foldM, sequence_, mapM_
    ) where 
import Prelude hiding (length, head, last, null, tail, map, filter, concat, 
                       any, lookup, init, all, foldl, foldr, foldl1, foldr1,
                       maximum, minimum, iterate, span, break, takeWhile,
                       dropWhile, reverse, zip, zipWith, sequence,
                       sequence_, mapM, mapM_, concatMap, and, or, sum,
                       product, repeat, replicate, cycle, take, drop,
                       splitAt, elem, notElem, unzip, lines, words,
                       unlines, unwords)
import qualified Data.Foldable as F
import Data.Monoid
import Data.Maybe
import qualified Data.List as L

{- | This is the primary class for structures that are to be considered 
foldable.  A minimum complete definition provides 'foldl' and 'foldr'.

Instances of 'FoldableLL' can be folded, and can be many and varied.

These functions are used heavily in "Data.ListLike". -}
class FoldableLL full item | full -> item where
    {- | Left-associative fold -}
    foldl :: (a -> item -> a) -> a -> full -> a

    {- | Strict version of 'foldl'. -}
    foldl' :: (a -> item -> a) -> a -> full -> a
    -- This implementation from Data.Foldable
    foldl' f a xs = foldr f' id xs a
        where f' x k z = k $! f z x

    -- | A variant of 'foldl' with no base case.  Requires at least 1
    -- list element.
    foldl1 :: (item -> item -> item) -> full -> item
    -- This implementation from Data.Foldable
    foldl1 f xs = fromMaybe (error "fold1: empty structure")
                    (foldl mf Nothing xs)
           where mf Nothing y = Just y
                 mf (Just x) y = Just (f x y)
    {- | Right-associative fold -}
    foldr :: (item -> b -> b) -> b -> full -> b

    -- | Strict version of 'foldr'
    foldr' :: (item -> b -> b) -> b -> full -> b
    -- This implementation from Data.Foldable
    foldr' f a xs = foldl f' id xs a
        where f' k x z = k $! f x z

    -- | Like 'foldr', but with no starting value
    foldr1 :: (item -> item -> item) -> full -> item
    -- This implementation from Data.Foldable
    foldr1 f xs = fromMaybe (error "foldr1: empty structure")
                    (foldr mf Nothing xs)
           where mf x Nothing = Just x
                 mf x (Just y) = Just (f x y)


    ------------------------------ Special folds
    {- | Flatten the structure. -}
    concat :: (FoldableLL full' full, Monoid full) => full' -> full
    concat = fold

    {- | Map a function over the items and concatenate the results.
         See also 'rigidConcatMap'.-}
    concatMap :: (FoldableLL full item, Monoid full') =>
                 (item -> full') -> full -> full'
    concatMap = foldMap

    {- | Like 'concatMap', but without the possibility of changing
         the type of the item.  This can have performance benefits
         for some things such as ByteString. -}
    rigidConcatMap :: (Monoid full) => (item -> full) -> full -> full
    rigidConcatMap = concatMap

    {- | True if any items satisfy the function -}
    any :: (item -> Bool) -> full -> Bool
    any p = getAny . foldMap (Any . p)

    {- | True if all items satisfy the function -}
    all :: (item -> Bool) -> full -> Bool
    all p = getAll . foldMap (All . p)

    {- | The maximum value of the list -}
    maximum :: Ord item => full -> item
    maximum = foldr1 max

    {- | The minimum value of the list -}
    minimum :: Ord item => full -> item
    minimum = foldr1 min


    ------------------------------ Searching
    {- | True if the item occurs in the list -}
    elem :: Eq item => item -> full -> Bool
    elem i = any (== i)

    {- | True if the item does not occur in the list -}
    notElem :: Eq item => item -> full -> Bool
    notElem i = all (/= i)

    ------------------------------ Conversions

    {- | Converts the structure to a list.  This is logically equivolent
         to 'fromListLike', but may have a more optimized implementation. -}
    toList :: full -> [item]
    toList = foldr (:) []
    {-# INLINE toList #-}

{- | Combine the elements of a structure using a monoid.
     @'fold' = 'foldMap' id@ -}
fold :: (FoldableLL full item, Monoid item) => full -> item
fold = foldMap id

{- | Map each element to a monoid, then combine the results -}
foldMap :: (FoldableLL full item, Monoid m) => (item -> m) -> full -> m
foldMap f = foldr (mappend . f) mempty

instance FoldableLL [a] a where
    foldl = L.foldl
    foldl1 = L.foldl1
    foldl' = L.foldl'
    foldr = L.foldr
    foldr1 = L.foldr1
    foldr' = F.foldr'
{-
instance (F.Foldable f) => FoldableLL (f a) a where
    foldl = F.foldl
    foldl1 = F.foldl1
    foldl' = F.foldl'
    foldr = F.foldr
    foldr1 = F.foldr1
    foldr' = F.foldr'
-}

-- Based on http://stackoverflow.com/a/12881193/1333025
{- | Monadic version of left fold, similar to 'Control.Monad.foldM'. -}
foldM :: (Monad m, FoldableLL full item) => (a -> item -> m a) -> a -> full -> m a
foldM f z xs = foldr (\x rest a -> f a x >>= rest) return xs z

{- | A map in monad space, discarding results. -}
mapM_ :: (Monad m, FoldableLL full item) => (item -> m b) -> full -> m ()
mapM_ func = foldr ((>>) . func) (return ())

{- | Evaluate each action, ignoring the results.
   Same as @'mapM_' 'id'@. -}
sequence_ :: (Monad m, FoldableLL full (m item)) => full -> m ()
sequence_ = mapM_ id
