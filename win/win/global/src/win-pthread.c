#include <stdio.h>
#include <string.h>
#include "pthread.h"
#include "implement.h"

#if defined(_MSC_VER)
#define MS_VC_EXCEPTION 0x406D1388

#pragma pack(push,8)
typedef struct tagTHREADNAME_INFO
{
  DWORD dwType; // Must be 0x1000.
  LPCSTR szName; // Pointer to name (in user addr space).
  DWORD dwThreadID; // Thread ID (-1=caller thread).
  DWORD dwFlags; // Reserved for future use, must be zero.
} THREADNAME_INFO;
#pragma pack(pop)

void
SetThreadName( DWORD dwThreadID, char* threadName)
{
  THREADNAME_INFO info;
  info.dwType = 0x1000;
  info.szName = threadName;
  info.dwThreadID = dwThreadID;
  info.dwFlags = 0;

  __try
  {
    RaiseException( MS_VC_EXCEPTION, 0, sizeof(info)/sizeof(ULONG_PTR), (ULONG_PTR*)&info );
  }
  __except(EXCEPTION_EXECUTE_HANDLER)
  {
  }
}
#endif

#if defined(PTW32_COMPATIBILITY_BSD) || defined(PTW32_COMPATIBILITY_TRU64)
int
pthread_setname_np(pthread_t thr, const char *name, void *arg)
{
  ptw32_mcs_local_node_t threadLock;
  int len;
  int result;
  char tmpbuf[PTHREAD_MAX_NAMELEN_NP];
  char * newname;
  char * oldname;
  ptw32_thread_t * tp;
#if defined(_MSC_VER)
  DWORD Win32ThreadID;
#endif

  /*
   * Validate the thread id. This method works for pthreads-win32 because
   * pthread_kill and pthread_t are designed to accommodate it, but the
   * method is not portable.
   */
  result = pthread_kill (thr, 0);
  if (0 != result)
    {
      return result;
    }

  /*
   * According to the MSDN description for snprintf()
   * where count is the second parameter:
   * If len < count, then len characters are stored in buffer, a null-terminator is appended, and len is returned.
   * If len = count, then len characters are stored in buffer, no null-terminator is appended, and len is returned.
   * If len > count, then count characters are stored in buffer, no null-terminator is appended, and a negative value is returned.
   *
   * This is different to the POSIX behaviour which returns the number of characters that would have been written in all cases.
   */
  len = snprintf(tmpbuf, PTHREAD_MAX_NAMELEN_NP-1, name, arg);
  tmpbuf[PTHREAD_MAX_NAMELEN_NP-1] = '\0';
  if (len < 0)
    {
      return EINVAL;
    }

  newname = _strdup(tmpbuf);

#if defined(_MSC_VER)
  Win32ThreadID = pthread_getw32threadid_np (thr);
  if (Win32ThreadID)
    {
      SetThreadName(Win32ThreadID, newname);
    }
#endif

  tp = (ptw32_thread_t *) thr.p;

  ptw32_mcs_lock_acquire (&tp->threadLock, &threadLock);

  oldname = tp->name;
  tp->name = newname;
  if (oldname)
    {
      free(oldname);
    }

  ptw32_mcs_lock_release (&threadLock);

  return 0;
}
#else
int
pthread_setname_np(pthread_t thr, const char *name)
{
  ptw32_mcs_local_node_t threadLock;
  int result;
  char * newname;
  char * oldname;
  ptw32_thread_t * tp;
#if defined(_MSC_VER)
  DWORD Win32ThreadID;
#endif

  /*
   * Validate the thread id. This method works for pthreads-win32 because
   * pthread_kill and pthread_t are designed to accommodate it, but the
   * method is not portable.
   */
  result = pthread_kill (thr, 0);
  if (0 != result)
    {
      return result;
    }

  newname = _strdup(name);

#if defined(_MSC_VER)
  Win32ThreadID = pthread_getw32threadid_np (thr);

  if (Win32ThreadID)
    {
      SetThreadName(Win32ThreadID, newname);
    }
#endif

  tp = (ptw32_thread_t *) thr.p;

  ptw32_mcs_lock_acquire (&tp->threadLock, &threadLock);

  oldname = tp->name;
  tp->name = newname;
  if (oldname)
    {
      free(oldname);
    }

  ptw32_mcs_lock_release (&threadLock);

  return 0;
}
#endif
