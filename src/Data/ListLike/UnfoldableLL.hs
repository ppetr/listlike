{-# LANGUAGE MultiParamTypeClasses
            ,FunctionalDependencies
            ,FlexibleInstances #-}
module Data.ListLike.UnfoldableLL 
    (-- * FoldableLL Class
     UnfoldableLL(..),
     -- * Utilities
     mapM, replicate, genericReplicate
    ) where 
import Prelude hiding (length, head, last, null, tail, map, filter, concat, 
                       any, lookup, init, all, foldl, foldr, foldl1, foldr1,
                       maximum, minimum, iterate, span, break, takeWhile,
                       dropWhile, reverse, zip, zipWith, sequence,
                       sequence_, mapM, mapM_, concatMap, and, or, sum,
                       product, repeat, replicate, cycle, take, drop,
                       splitAt, elem, notElem, unzip, lines, words,
                       unlines, unwords)
import Control.Applicative hiding (empty)
import Control.Monad.Identity (Identity(..), runIdentity)
import qualified Data.Traversable as T
import Data.Monoid
import Data.Maybe
import qualified Data.List as L
import Data.ListLike.FoldableLL
import Data.ListLike.TraversableLL

class (TraversableLL full item) =>
    UnfoldableLL full item | full -> item where

    unfoldr :: (a -> Maybe (item, a)) -> a -> full
    -- | O(n) Like 'unfold'r, 'unfoldr'N builds a collection from a seed
    -- value.  In addition, it is given a likely upper bound length of the
    -- result in its first argument. This function is usually more efficient
    -- than unfoldr when the maximum length of the result is known and
    -- correct.
    -- If the first argument is negative, the bound is not known and
    -- 'unfoldrN' behaves just like 'unfoldr'.
    unfoldrN :: Int -> (a -> Maybe (item, a)) -> a -> full
    unfoldrN _ = unfoldr

    traverse
      :: (Applicative f, FoldableLL full1 item1)
      => (item1 -> f item) -> full1 -> f full
    traverse f = fmap fromList . T.traverse f . toList
    {-# INLINE traverse #-}

    {- | Apply a function to each element, returning any other
         valid 'ListLike'.  'rigidMap' will always be at least
         as fast, if not faster, than this function and is recommended
         if it will work for your purposes.  See also 'mapM'. -}
    map
      :: (FoldableLL full1 item1)
      => (item1 -> item) -> full1 -> full
    map f = runIdentity . traverse (Identity . f)
    {-# INLINE map #-}

    ------------------------------ Creation
    {- | The empty list -}
    empty :: (UnfoldableLL full item) => full
    empty = unfoldrN 0 (\() -> Nothing) ()

    {- | Creates a single-element list out of an element -}
    singleton :: (UnfoldableLL full item) => item -> full
    singleton x = replicate 1 x

    {- | Generates the structure from a list. -}
    fromList :: [item] -> full
    fromList = unfoldr u
      where
        u []     = Nothing
        u (x:xs) = Just (x, xs)
    {-# INLINE fromList #-}

    {- | Converts one ListLike to another.  See also 'toList'.
         Default implementation is @fromListLike = fromList . toList@ -}
    fromListLike :: (FoldableLL full' item) => full' -> full
    fromListLike = fromList . toList
    {-# INLINE fromListLike #-}

mapM 
  :: (Monad m, FoldableLL full1 item1, UnfoldableLL full item)
  => (item1 -> m item) -> full1 -> m full
mapM f = unwrapMonad . traverse (WrapMonad . f)
{-# INLINE mapM #-}


------------------------------ Infinite lists
{- | Generate a structure with the specified length with every element
set to the item passed in.  See also 'genericReplicate' -}
replicate :: (UnfoldableLL full item) => Int -> item -> full
replicate = genericReplicate


{- | Generic version of 'replicate' -}
genericReplicate :: (UnfoldableLL full item, Integral a) => a -> item -> full
genericReplicate count x = unfoldrN (max 0 $ fromIntegral count) f count
  where
    f n | n <= 0    = Nothing
        | otherwise = Just (x, n - 1)



instance UnfoldableLL [a] a where
    unfoldr = L.unfoldr
    singleton = (: [])
    empty = []
    map f = L.map f . toList
    fromList = id
