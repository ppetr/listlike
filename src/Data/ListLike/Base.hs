{-# LANGUAGE ScopedTypeVariables
            ,MultiParamTypeClasses
            ,FunctionalDependencies
            ,FlexibleInstances
            ,BangPatterns
            ,FlexibleContexts #-}

{-
Copyright (C) 2007 John Goerzen <jgoerzen@complete.org>

All rights reserved.

For license and copyright information, see the file COPYRIGHT

-}

{- |
   Module     : Data.ListLike.Base
   Copyright  : Copyright (C) 2007 John Goerzen
   License    : BSD3

   Maintainer : John Lato <jwlato@gmail.com>
   Stability  : provisional
   Portability: portable

Generic operations over list-like structures

Written by John Goerzen, jgoerzen\@complete.org
-}

module Data.ListLike.Base 
    (
    ListLike(..),
    InfiniteListLike(..),
    mapM, rigidMapM,
    zip, zipWith, sequence_
    ) where
import Prelude hiding (length, head, last, null, tail, map, filter, concat, 
                       any, lookup, init, all, foldl, foldr, foldl1, foldr1,
                       maximum, minimum, iterate, span, break, takeWhile,
                       dropWhile, reverse, zip, zipWith, sequence,
                       sequence_, mapM, mapM_, concatMap, and, or, sum,
                       product, repeat, replicate, cycle, take, drop,
                       splitAt, elem, notElem, unzip, lines, words,
                       unlines, unwords)
import qualified Data.List as L
import Data.ListLike.FoldableLL
import Data.ListLike.TraversableLL
import Data.ListLike.UnfoldableLL
import qualified Control.Applicative as A
import qualified Control.Monad as M
import qualified Control.Monad.Identity as M
import Data.Monoid
import Data.Maybe

{- | The class implementing list-like functions.

It is worth noting that types such as 'Data.Map.Map' can be instances of
'ListLike'.  Due to their specific ways of operating, they may not behave
in the expected way in some cases.  For instance, 'cons' may not increase
the size of a map if the key you have given is already in the map; it will
just replace the value already there.

Implementators must define at least:

* singleton

* head

* tail

* null or genericLength
-}
class (UnfoldableLL full item, Monoid full) =>
    ListLike full item | full -> item where

    ------------------------------ basic functions

    {- | Like (:) for lists: adds an element to the beginning of a list -}
    cons :: item -> full -> full
    cons item l = append (singleton item) l

    {- | Adds an element to the *end* of a 'ListLike'. -}
    snoc :: full -> item -> full
    snoc l item = append l (singleton item)

    {- | Combines two lists.  Like (++). -}
    append :: full -> full -> full 
    append = mappend

    {- | Gives all elements after the head. -}
    tail :: full -> full 

    {- | All elements of the list except the last one.  See also 'inits'. -}
    init :: full -> full
    init l
        | null l = error "init: empty list"
        | null xs = empty
        | otherwise = cons (head l) (init xs)
        where xs = tail l

    ------------------------------ List Transformations

    {- | Reverse the elements in a list. -}
    reverse :: full -> full 
    reverse l = rev l empty
        where rev rl a
                | null rl = a
                | otherwise = rev (tail rl) (cons (head rl) a)
    {- | Add an item between each element in the structure -}
    intersperse :: item -> full -> full
    intersperse sep l
        | null l = empty
        | null xs = singleton x
        | otherwise = cons x (cons sep (intersperse sep xs))
        where x = head l
              xs = tail l

    ------------------------------ Reducing Lists (folds)
    -- See also functions in FoldableLLL

    ------------------------------ Sublists
    {- | Takes the first n elements of the list.  See also 'genericTake'. -}
    take :: Int -> full -> full
    take = genericTake

    {- | Drops the first n elements of the list.  See also 'genericDrop' -}
    drop :: Int -> full -> full
    drop = genericDrop

    {- | Equivalent to @('take' n xs, 'drop' n xs)@.  See also 'genericSplitAt'. -}
    splitAt :: Int -> full -> (full, full)
    splitAt = genericSplitAt

    {- | Returns all elements at start of list that satisfy the function. -}
    takeWhile :: (item -> Bool) -> full -> full
    takeWhile func l 
        | null l = empty
        | func x = cons x (takeWhile func (tail l))
        | otherwise = empty
        where x = head l

    {- | Drops all elements form the start of the list that satisfy the
       function. -}
    dropWhile :: (item -> Bool) -> full -> full
    dropWhile func l
        | null l = empty
        | func (head l) = dropWhile func (tail l)
        | otherwise = l

    {- | The equivalent of @('takeWhile' f xs, 'dropWhile' f xs)@ -}
    span :: (item -> Bool) -> full -> (full, full)
    span func l
        | null l = (empty, empty)
        | func x = (cons x ys, zs) 
        | otherwise = (empty, l)
       where (ys, zs) = span func (tail l)
             x = head l
    {- | The equivalent of @'span' ('not' . f)@ -}
    break :: (item -> Bool) -> full -> (full, full)
    break p = span (not . p)

    {- | Split a list into sublists, each which contains equal arguments.
       For order-preserving types, concatenating these sublists will produce
       the original list. See also 'groupBy'. -}
    group :: (ListLike full' full, Eq item) => full -> full'
    group = groupBy (==)

    {- | All initial segments of the list, shortest first -}
    inits :: (ListLike full' full) => full -> full'
    inits l
        | null l = singleton empty
        | otherwise =
            append (singleton empty)
                   (map (cons (head l)) theinits)
            where theinits = asTypeOf (inits (tail l)) [l]

    {- | All final segnemts, longest first -}
    tails :: ListLike full' full => full -> full'
    tails l
        | null l = singleton empty
        | otherwise = cons l (tails (tail l))

    ------------------------------ Predicates

    {- | True when the first list is at the beginning of the second. -}
    isSuffixOf :: Eq item => full -> full -> Bool
    isSuffixOf needle haystack = isPrefixOf (reverse needle) (reverse haystack)

    {- | True when the first list is wholly containted within the second -}
    isInfixOf :: Eq item => full -> full -> Bool
    isInfixOf needle haystack = 
        any (isPrefixOf needle) thetails
        where thetails = asTypeOf (tails haystack) [haystack]

    ------------------------------ Searching

    {- | Returns only the elements that satisfy the function. -}
    filter :: (item -> Bool) -> full -> full 
    filter func l 
        | null l = empty
        | func (head l) = cons (head l) (filter func (tail l))
        | otherwise = filter func (tail l)

    {- | Returns the lists that do and do not satisfy the function.
       Same as @('filter' p xs, 'filter' ('not' . p) xs)@ -}
    partition :: (item -> Bool) -> full -> (full, full)
    partition p xs = (filter p xs, filter (not . p) xs)

    ------------------------------ "Set" operations
    {- | Removes duplicate elements from the list.  See also 'nubBy' -}
    nub :: Eq item => full -> full
    nub = nubBy (==)

    {- | Removes the first instance of the element from the list.
       See also 'deleteBy' -}
    delete :: Eq item => item -> full -> full
    delete = deleteBy (==)

    {- | List difference.  Removes from the first list the first instance
       of each element of the second list.  See '(\\)' and 'deleteFirstsBy' -}
    deleteFirsts :: Eq item => full -> full -> full
    deleteFirsts = foldl (flip delete)

    {- | List union: the set of elements that occur in either list.
         Duplicate elements in the first list will remain duplicate.
         See also 'unionBy'. -}
    union :: Eq item => full -> full -> full
    union = unionBy (==)

    {- | List intersection: the set of elements that occur in both lists.
         See also 'intersectBy' -}
    intersect :: Eq item => full -> full -> full
    intersect = intersectBy (==)

    ------------------------------ Ordered lists
    {- | Sorts the list.  On data types that do not preserve ordering,
         or enforce their own ordering, the result may not be what
         you expect.  See also 'sortBy'. -}
    sort :: Ord item => full -> full
    sort = sortBy compare

    {- | Inserts the element at the last place where it is still less than or
         equal to the next element.  On data types that do not preserve 
         ordering, or enforce their own ordering, the result may not
         be what you expect.  On types such as maps, this may result in
         changing an existing item.  See also 'insertBy'. -}
    insert :: Ord item => item -> full -> full 
    insert = insertBy compare

    ------------------------------ Generalized functions
    {- | Generic version of 'nub' -}
    nubBy :: (item -> item -> Bool) -> full -> full
    nubBy f l = nubBy' l (empty :: full)
     where
      nubBy' ys xs
        | null ys              = empty
        | any (f (head ys)) xs = nubBy' (tail ys) xs
        | otherwise            = let y = head ys
                                 in  cons y (nubBy' (tail ys) (cons y xs))
{-
    nubBy f l
        | null l = empty
        | otherwise =
            cons (head l) (nubBy f (filter (\y -> not (f (head l) y)) (tail l)))
-}

    {- | Generic version of 'deleteBy' -}
    deleteBy :: (item -> item -> Bool) -> item -> full -> full
    deleteBy func i l
        | null l = empty
        | otherwise =
            if func i (head l)
               then tail l
               else cons (head l) (deleteBy func i (tail l))

    {- | Generic version of 'deleteFirsts' -}
    deleteFirstsBy :: (item -> item -> Bool) -> full -> full -> full
    deleteFirstsBy func = foldl (flip (deleteBy func))

    {- | Generic version of 'union' -}
    unionBy :: (item -> item -> Bool) -> full -> full -> full
    unionBy func x y =
        append x $ foldl (flip (deleteBy func)) (nubBy func y) x

    {- | Generic version of 'intersect' -}
    intersectBy :: (item -> item -> Bool) -> full -> full -> full
    intersectBy func xs ys = filter (\x -> any (func x) ys) xs

    {- | Generic version of 'group'. -}
    groupBy :: (ListLike full' full, Eq item) => 
                (item -> item -> Bool) -> full -> full'
    groupBy eq l
        | null l = empty
        | otherwise = cons (cons x ys) (groupBy eq zs)
                      where (ys, zs) = span (eq x) xs
                            x = head l
                            xs = tail l

    {- | Sort function taking a custom comparison function -}
    sortBy :: (item -> item -> Ordering) -> full -> full 
    sortBy cmp = foldr (insertBy cmp) empty

    {- | Like 'insert', but with a custom comparison function -}
    insertBy :: (item -> item -> Ordering) -> item ->
                full -> full 
    insertBy cmp x ys
        | null ys = singleton x
        | otherwise = case cmp x (head ys) of
                        GT -> cons (head ys) (insertBy cmp x (tail ys))
                        _ ->  cons x ys

    ------------------------------ Generic Operations

    {- | Generic version of 'take' -}
    genericTake :: Integral a => a -> full -> full
    genericTake n l
        | n <= 0 = empty
        | null l = empty
        | otherwise = cons (head l) (genericTake (n - 1) (tail l))

    {- | Generic version of 'drop' -}
    genericDrop :: Integral a => a -> full -> full
    genericDrop n l 
        | n <= 0 = l
        | null l = l
        | otherwise = genericDrop (n - 1) (tail l)

    {- | Generic version of 'splitAt' -}
    genericSplitAt :: Integral a => a -> full -> (full, full)
    genericSplitAt n l = (genericTake n l, genericDrop n l)

{-
instance (ListLike full item) => Monad full where
    m >>= k = foldr (append . k) empty m
    m >> k = foldr (append . (\_ -> k)) empty m
    return x = singleton x
    fail _ = empty

instance (ListLike full item) => M.MonadPlus full where
    mzero = empty
    mplus = append
-}

{- | An extension to 'ListLike' for those data types that are capable
of dealing with infinite lists.  Some 'ListLike' functions are capable
of working with finite or infinite lists.  The functions here require
infinite list capability in order to work at all. -}
class (ListLike full item) => InfiniteListLike full item | full -> item where
    {- | An infinite list of repeated calls of the function to args -}
    iterate :: (item -> item) -> item -> full
    iterate f x = cons x (iterate f (f x))

    {- | An infinite list where each element is the same -}
    repeat :: item -> full
    repeat x = xs
        where xs = cons x xs

    {- | Converts a finite list into a circular one -}
    cycle :: full -> full
    cycle xs 
        | null xs = error "ListLike.cycle: empty list"
        | otherwise = xs' where xs' = append xs xs'

--------------------------------------------------
-- This instance is here due to some default class functions

instance ListLike [a] a where
    cons x l = x : l
    snoc l x = l ++ [x]
    append = (++)
    tail = L.tail
    init = L.init
    reverse = L.reverse
    intersperse = L.intersperse
    -- fromListLike = toList
    -- concatMap func = fromList . L.concatMap func
    -- fold
    -- foldMap
    take = L.take
    drop = L.drop
    splitAt = L.splitAt
    takeWhile = L.takeWhile
    dropWhile = L.dropWhile
    span = L.span
    break = L.break
    group = fromList . L.group
    inits = fromList . L.inits
    tails = fromList . L.tails
    isSuffixOf = L.isSuffixOf
    isInfixOf = L.isInfixOf
    filter = L.filter
    partition = L.partition
    -- mapM = M.mapM
    nub = L.nub
    delete = L.delete
    deleteFirsts = (L.\\)
    union = L.union
    intersect = L.intersect
    sort = L.sort
    groupBy func = fromList . L.groupBy func
    unionBy = L.unionBy
    intersectBy = L.intersectBy
    sortBy = L.sortBy
    insert = L.insert

--------------------------------------------------
-- These utils are here instead of in Utils.hs because they are needed
-- by default class functions

{- | Takes two lists and returns a list of corresponding pairs. -}
zip :: (ListLike full item,
          ListLike fullb itemb,
          ListLike result (item, itemb)) =>
          full -> fullb -> result
zip = zipWith (\a b -> (a, b))

{- | Takes two lists and combines them with a custom combining function -}
zipWith :: (ListLike full item,
            ListLike fullb itemb,
            ListLike result resultitem) =>
            (item -> itemb -> resultitem) -> full -> fullb -> result
zipWith f a b
    | null a = empty
    | null b = empty
    | otherwise = cons (f (head a) (head b)) (zipWith f (tail a) (tail b))
