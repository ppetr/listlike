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
     fold, foldMap, headMaybe, lastMaybe,
     -- * Folding actinos
     -- ** Applicative actions
     traverse_, for_, sequenceA_, asum,
     -- ** Monadic actions
     foldM, sequence_, mapM_, forM_, msum
    ) where 
import Prelude hiding (length, head, last, null, tail, map, filter, concat, 
                       any, lookup, init, all, foldl, foldr, foldl1, foldr1,
                       maximum, minimum, iterate, span, break, takeWhile,
                       dropWhile, reverse, zip, zipWith, sequence,
                       sequence_, mapM, mapM_, concatMap, and, or, sum,
                       product, repeat, replicate, cycle, take, drop,
                       splitAt, elem, notElem, unzip, lines, words,
                       unlines, unwords)
import Control.Applicative
import Control.Monad hiding (mapM, mapM_, sequence_, foldM, forM_, msum)
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
    foldl f a xs = foldr f' id xs a
        where f' x k z = k $ f z x
    {-# INLINE foldl #-}

    {- | Strict version of 'foldl'. -}
    foldl' :: (a -> item -> a) -> a -> full -> a
    -- This implementation from Data.Foldable
    foldl' f a xs = foldr f' id xs a
        where f' x k z = k $! f z x
    {-# INLINE foldl' #-}

    -- | A variant of 'foldl' with no base case.  Requires at least 1
    -- list element.
    foldl1 :: (item -> item -> item) -> full -> item
    -- This implementation from Data.Foldable
    foldl1 f xs = fromMaybe (error "fold1: empty structure")
                    (foldl mf Nothing xs)
           where mf Nothing y = Just y
                 mf (Just x) y = Just (f x y)
    {-# INLINE foldl1 #-}

    {- | Left-associative fold that allows premature termination. -}
    foldlE :: (a -> c) -> (a -> item -> Either c a) -> a -> full -> c
    foldlE fin f a xs = foldr f' fin xs a
        where f' x k z = case f z x of
                            Right a     -> k a
                            Left c      -> c

    {- | Left-associative strict fold that allows premature termination. -}
    foldlE' :: (a -> c) -> (a -> item -> Either c a) -> a -> full -> c
    foldlE' fin f = foldlE fin (f $!)
{-
    foldlE' fin f a xs = foldr f' fin xs a
        where f' x k z = case f z x of
                            Right a     -> k $! a
                            Left c      -> c
-}
    {-# INLINE foldlE' #-}

    {- | Right-associative fold -}
    foldr :: (item -> b -> b) -> b -> full -> b
    foldr f a xs = foldl f' id xs a
        where f' k x z = k $ f x z
    {-# INLINE foldr #-}

    -- | Strict version of 'foldr'
    foldr' :: (item -> b -> b) -> b -> full -> b
    -- This implementation from Data.Foldable
    foldr' f a xs = foldl f' id xs a
        where f' k x z = k $! f x z
    {-# INLINE foldr' #-}

    -- | Like 'foldr', but with no starting value
    foldr1 :: (item -> item -> item) -> full -> item
    -- This implementation from Data.Foldable
    foldr1 f xs = fromMaybe (error "foldr1: empty structure")
                    (foldr mf Nothing xs)
           where mf x Nothing = Just x
                 mf x (Just y) = Just (f x y)
    {-# INLINE foldr1 #-}

    ------------------------------ basic functions derivable from fold

    {- | Extracts the first element of a 'ListLike'. -}
    head :: full -> item
    head = foldr const (error "'head' called on an empty collection")
    {-# INLINE head #-}

    {- | Extracts the last element of a 'ListLike'. -}
    last :: full -> item
    last = foldl' (const id) (error "'last' called on an empty collection")
    {-# INLINE last #-}

    {- | Tests whether the list is empty. -}
    null :: full -> Bool
    null = foldr (\_ _ -> False) True
    {-# INLINE null #-}

    {- | Length of the list.  See also 'genericLength'. -}
    length :: full -> Int
    length = genericLength
    {-# INLINE  length #-}

    {- | Length of the list -}
    genericLength :: (Num a) => full -> a
    genericLength = foldl' (\n _ -> n + 1) 0
    {-# INLINE genericLength #-}

    {- | The element at 0-based index @i@.  Raises an exception if @i@ is out
         of bounds.  Like @(!!)@ for lists. -}
    index :: full -> Int -> item
    index l n = foldlE' err f n l
      where
        f 0 x = Left x
        f i _ = Right $! i - 1
        err = error $ "index: index " ++ show n ++ " not found"
    {-
    index l n | n < 0       = err
              | otherwise   = foldr f (const err) l n
      where
        f x k 0 = x
        f _ k i = k $! i - 1
        err = error $ "index: index " ++ show n ++ " not found"
    -}
    {-# INLINE index #-}

    ------------------------------ Searching

    {- | Take a function and return the first matching element, or Nothing
       if there is no such element. -}
    find :: (item -> Bool) -> full -> Maybe item
    find p = foldr (\x r -> if p x then Just x else r) Nothing
    {-# INLINE find #-}

    {- | Take a function and return the index of the first matching element,
         or @Nothing@ if no element matches. -}
    findIndex :: (item -> Bool) -> full -> Maybe Int
    findIndex p = foldlE' (const Nothing) f 0
      where
        f i x | p x         = Left (Just i)
              | otherwise   = Right $ i + 1
{-
    findIndex p l = foldr f (const Nothing) l 0
      where
        f x k i | p x       = Just i
                | otherwise = k $! i + 1
-}
    {-# INLINE findIndex #-}


    {- | Returns the indices of all elements satisfying the function -}
    findIndices :: (item -> Bool) -> full -> [Int]
    findIndices p l = foldr f (const []) l 0
      where
        f x k i | p x          = i : (k $! i + 1)
                | otherwise    =     (k $! i + 1)
    {-# INLINE findIndices #-}


    {- | Returns the index of the element, if it exists. -}
    elemIndex :: (Eq item) => item -> full -> Maybe Int
    elemIndex e l = findIndex (== e) l
    {-# INLINE elemIndex #-}

    {- | Returns the indices of the matching elements.  See also 
       'findIndices' -}
    elemIndices :: (Eq item) => item -> full -> [Int]
    elemIndices i l = findIndices (== i) l
    {-# INLINE elemIndices #-}

    ------------------------------ Predicates
    
    {- | True when the first list is at the beginning of the second. -}
    isPrefixOf :: (Eq item) => full -> full -> Bool
    isPrefixOf needle haystack = foldr f null haystack (toList needle)
      where
        f x k []        = True
        f x k (n:ns)
            | n == x    = k ns
            | otherwise = False
    {-# INLINE isPrefixOf #-}

    ------------------------------ Special folds
    {- | Flatten the structure. -}
    concat :: (FoldableLL full' full, Monoid full) => full' -> full
    concat = fold
    {-# INLINE concat #-}

    {- | Map a function over the items and concatenate the results.
         See also 'rigidConcatMap'.-}
    concatMap :: (FoldableLL full item, Monoid full') =>
                 (item -> full') -> full -> full'
    concatMap = foldMap
    {-# INLINE concatMap #-}

    {- | Like 'concatMap', but without the possibility of changing
         the type of the item.  This can have performance benefits
         for some things such as ByteString. -}
    rigidConcatMap :: (Monoid full) => (item -> full) -> full -> full
    rigidConcatMap = concatMap
    {-# INLINE rigidConcatMap #-}

    {- | True if any items satisfy the function -}
    any :: (item -> Bool) -> full -> Bool
    any p = getAny . foldMap (Any . p)
    {-# INLINE any #-}

    {- | True if all items satisfy the function -}
    all :: (item -> Bool) -> full -> Bool
    all p = getAll . foldMap (All . p)
    {-# INLINE all #-}

    {- | The maximum value of the list -}
    maximum :: Ord item => full -> item
    maximum = foldr1 max
    {-# INLINE maximum #-}

    {- | The minimum value of the list -}
    minimum :: Ord item => full -> item
    minimum = foldr1 min
    {-# INLINE minimum #-}


    ------------------------------ Searching
    {- | True if the item occurs in the list -}
    elem :: Eq item => item -> full -> Bool
    elem i = any (== i)
    {-# INLINE elem #-}

    {- | True if the item does not occur in the list -}
    notElem :: Eq item => item -> full -> Bool
    notElem i = all (/= i)
    {-# INLINE notElem #-}

    ------------------------------ Conversions

    {- | Converts the structure to a list.  This is logically equivolent
         to 'fromListLike', but may have a more optimized implementation. -}
    toList :: full -> [item]
    toList = foldr (:) []
    {-# INLINE toList #-}

    {- | Converts the structure to a list. In addition, returns
         the length of the returned list, if its computation of
         doesn't take longer than /O(1)/. This is useful if we
         want to use 'fromListN' or 'unfoldrN' later.
    -}
    toListN :: full -> (Maybe Int, [item])
    toListN = ((,) Nothing) . toList
    {-# INLINE toListN #-}

{- | Combine the elements of a structure using a monoid.
     @'fold' = 'foldMap' id@ -}
fold :: (FoldableLL full item, Monoid item) => full -> item
fold = foldMap id
{-# INLINE fold #-}

{- | Map each element to a monoid, then combine the results -}
foldMap :: (FoldableLL full item, Monoid m) => (item -> m) -> full -> m
foldMap f = foldr (mappend . f) mempty
{-# INLINE foldMap #-}

{- | Safely extracts the first element. -}
headMaybe :: (FoldableLL full item) => full -> Maybe item
headMaybe l | null l    = Nothing
            | otherwise = Just $ head l
{-# INLINE headMaybe #-}

{- | Safely extracts the last element. -}
lastMaybe :: (FoldableLL full item) => full -> Maybe item
lastMaybe l | null l    = Nothing
            | otherwise = Just $ last l
{-# INLINE lastMaybe #-}


instance FoldableLL [a] a where
    foldl = L.foldl
    {-# INLINE foldl #-}
    foldl1 = L.foldl1
    {-# INLINE foldl1 #-}
    foldl' = L.foldl'
    {-# INLINE foldl' #-}
    foldlE fin f = g
      where
        g z []      = fin z
        g z (x:xs)  = case f z x of
                        Left c  -> c
                        Right a -> g a xs
    {-# INLINE foldlE #-}

    foldr = L.foldr
    {-# INLINE foldr #-}
    foldr1 = L.foldr1
    {-# INLINE foldr1 #-}
    foldr' = F.foldr'
    {-# INLINE foldr' #-}

    head = L.head
    {-# INLINE head #-}
    last = L.last
    {-# INLINE last #-}
    null = L.null
    {-# INLINE null #-}
    length = L.length
    {-# INLINE length #-}
    find = L.find
    {-# INLINE find #-}
    index = (L.!!)
    {-# INLINE index #-}

    elemIndex = L.elemIndex
    {-# INLINE elemIndex #-}
    elemIndices item = L.elemIndices item
    {-# INLINE elemIndices #-}
    findIndex = L.findIndex
    {-# INLINE findIndex #-}

    isPrefixOf = L.isPrefixOf
    {-# INLINE isPrefixOf #-}

{-
instance (F.Foldable f) => FoldableLL (f a) a where
    foldl = F.foldl
    foldl1 = F.foldl1
    foldl' = F.foldl'
    foldr = F.foldr
    foldr1 = F.foldr1
    foldr' = F.foldr'
-}

-- Applicative actions -------------------------------------------------

{- | Map each element of a structure to an action, evaluate these actions
   from left to right, and ignore the results. -}
traverse_ 
    :: (Applicative f, FoldableLL full item)
    => (item -> f b) -> full -> f ()
traverse_ func = foldr ((*>) . func) (pure ())
{-# INLINE traverse_ #-}

{- | 'for_' is 'traverse_' with its arguments flipped. -}
for_
    :: (Applicative f, FoldableLL full item)
    => full -> (item -> f b) -> f ()
for_ = flip traverse_
{-# INLINE for_ #-}

{- | Evaluate each action in the structure from left to right, and ignore
   the results. -}
sequenceA_ 
    :: (Applicative f, FoldableLL full (f item))
    => full -> f ()
sequenceA_ = traverse_ id
{-# INLINE sequenceA_ #-}

{- | The sum of a collection of actions, generalizing concat.-}
asum 
    :: (Alternative f, FoldableLL full (f item))
    => full -> f item
asum = foldr (<|>) empty
{-# INLINE asum #-}


-- Monadic actions -----------------------------------------------------

-- Based on http://stackoverflow.com/a/12881193/1333025
{- | Monadic version of left fold, similar to 'Control.Monad.foldM'. -}
foldM :: (Monad m, FoldableLL full item) => (a -> item -> m a) -> a -> full -> m a
foldM f z xs = foldr (\x rest a -> f a x >>= rest) return xs z
{-# INLINE foldM #-}

{- | A map in monad space, discarding results. -}
mapM_ :: (Monad m, FoldableLL full item) => (item -> m b) -> full -> m ()
mapM_ func = foldr ((>>) . func) (return ())
{-# INLINE mapM_ #-}

{- | A map in monad space, discarding results. -}
forM_ :: (Monad m, FoldableLL full item) => full -> (item -> m b) -> m ()
forM_ = flip mapM_
{-# INLINE forM_ #-}

{- | Evaluate each action, ignoring the results.
   Same as @'mapM_' 'id'@. -}
sequence_ :: (Monad m, FoldableLL full (m item)) => full -> m ()
sequence_ = mapM_ id
{-# INLINE sequence_ #-}

{- | The sum of a collection of actions, generalizing concat.-}
msum 
    :: (MonadPlus m, FoldableLL full (m item))
    => full -> m item
msum = foldr mplus mzero
{-# INLINE msum #-}
