{-# LANGUAGE BangPatterns #-}

-- | This reference version is implemented with atomicModifyIORef and can be a useful
-- fallback if one of the other implementations needs to be debugged for a given
-- architecture.
module Data.Atomics.Counter.Reference       
       (AtomicCounter, CTicket,
        newCounter, readCounterForCAS, readCounter, peekCTicket,
        writeCounter, casCounter, incrCounter, incrCounter_)
       where

import Control.Monad (void)
import Data.IORef
-- import Data.Atomics
import System.IO.Unsafe (unsafePerformIO)

--------------------------------------------------------------------------------

-- type AtomicCounter = IORef Int
newtype AtomicCounter = AtomicCounter (IORef Int)

type CTicket = Int

{-# INLINE newCounter #-}
-- | Create a new counter initialized to the given value.
newCounter :: Int -> IO AtomicCounter
newCounter !n = fmap AtomicCounter $ newIORef n

{-# INLINE incrCounter #-}
-- | Try repeatedly until we successfully increment the counter by a given amount.
-- Returns the original value of the counter (pre-increment).
incrCounter :: Int -> AtomicCounter -> IO Int
incrCounter !bump !cntr =
    loop =<< readCounterForCAS cntr
  where
    loop tick = do
      (b,tick') <- casCounter cntr tick (peekCTicket tick + bump)
      if b then return (peekCTicket tick')
           else loop tick'

{-# INLINE incrCounter_ #-}
incrCounter_ :: Int -> AtomicCounter -> IO ()
incrCounter_ b c = void (incrCounter b c)

{-# INLINE readCounterForCAS #-}
-- | Just like the "Data.Atomics" CAS interface, this routine returns an opaque
-- ticket that can be used in CAS operations.
readCounterForCAS :: AtomicCounter -> IO CTicket
readCounterForCAS = readCounter

{-# INLINE peekCTicket #-}
-- | Opaque tickets cannot be constructed, but they can be destructed into values.
peekCTicket :: CTicket -> Int
peekCTicket !x = x

{-# INLINE readCounter #-}
-- | Equivalent to `readCounterForCAS` followed by `peekCTicket`.
readCounter :: AtomicCounter -> IO Int
readCounter (AtomicCounter r) = readIORef r

{-# INLINE writeCounter #-}
-- | Make a non-atomic write to the counter.  No memory-barrier.
writeCounter :: AtomicCounter -> Int -> IO ()
writeCounter (AtomicCounter r) !new = writeIORef r new

{-# INLINE casCounter #-}
-- | Compare and swap for the counter ADT.  Similar behavior to `casIORef`.
casCounter :: AtomicCounter -> CTicket -> Int -> IO (Bool, CTicket)
casCounter (AtomicCounter r) oldT !new =
  let old = oldT in 
  atomicModifyIORef' r $ \val -> 
    if   (val == old)
    then (new, (True, new))
    else (val, (False,val))


{-
{-# NOINLINE unsafeName #-}
unsafeName :: a -> Int
unsafeName x = unsafePerformIO $ do 
   sn <- makeStableName x
   return (hashStableName sn)

{-# NOINLINE ptrEq #-}
ptrEq :: a -> a -> Bool
ptrEq !x !y = I# (reallyUnsafePtrEquality# x y) == 1

-}
