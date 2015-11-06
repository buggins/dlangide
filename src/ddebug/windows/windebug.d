// just an attempt to implement D debugger for win32
module ddebug.windows.windebug;

version(Windows):
version(USE_WIN_DEBUG):

import dlangui.core.logger;
import win32.psapi;
import win32.windows;

import std.utf;
import core.thread;
import std.format;

class ModuleInfo {
    HANDLE hFile;
    ulong baseOfImage;
    ulong debugInfoFileOffset;
    ulong debugInfoSize;
    string imageFileName;
}

class DllInfo : ModuleInfo {
    ProcessInfo process;
    this(ProcessInfo baseProcess, ref DEBUG_EVENT di) {
        process = baseProcess;
        hFile = di.LoadDll.hFile;
        baseOfImage = cast(ulong)di.LoadDll.lpBaseOfDll;
        debugInfoFileOffset = di.LoadDll.dwDebugInfoFileOffset;
        debugInfoSize = di.LoadDll.nDebugInfoSize;
        ulong imageName = cast(ulong)di.LoadDll.lpImageName;
        Log.d(format("imageName address: %x", imageName));
        imageFileName = getFileNameFromHandle(hFile);
        //imageFileName = decodeZString(di.LoadDll.lpImageName, di.LoadDll.fUnicode != 0);
        //if (imageFileName.length == 0)
        //    imageFileName = getModuleFileName(process.hProcess, hFile);
    }
}

class ProcessInfo : ModuleInfo {
	HANDLE hProcess;
    uint processId;
	HANDLE hThread;
	ulong threadLocalBase;
	ulong startAddress; //LPTHREAD_START_ROUTINE

    this(ref DEBUG_EVENT di) {
	    hFile = di.CreateProcessInfo.hFile;
	    hProcess = di.CreateProcessInfo.hProcess;
        processId = di.dwProcessId;
	    hThread = di.CreateProcessInfo.hThread;
	    LPVOID lpBaseOfImage;
        baseOfImage = cast(ulong)di.CreateProcessInfo.lpBaseOfImage;
        debugInfoFileOffset = di.CreateProcessInfo.dwDebugInfoFileOffset;
        debugInfoSize = di.CreateProcessInfo.nDebugInfoSize;
        threadLocalBase = cast(ulong)di.CreateProcessInfo.lpThreadLocalBase;
        startAddress = cast(ulong)di.CreateProcessInfo.lpStartAddress;
        //imageFileName = decodeZString(di.CreateProcessInfo.lpImageName, di.CreateProcessInfo.fUnicode != 0);
        //if (imageFileName.length == 0)
        imageFileName = getFileNameFromHandle(hFile);
//            imageFileName = getModuleFileName(hProcess, hFile);
    }
}

private string decodeZString(void * pstr, bool isUnicode) {
    if (!pstr)
        return null;
    if (isUnicode) {
        wchar * ptr = cast(wchar*)pstr;
        wchar[] buf;
        for(; *ptr; ptr++)
            buf ~= *ptr;
        return toUTF8(buf);
    } else {
        char * ptr = cast(char*)pstr;
        char[] buf;
        for(; *ptr; ptr++)
            buf ~= *ptr;
        return buf.dup;
    }
}

private string getModuleFileName(HANDLE hProcess, HANDLE hFile) {
    //wchar[4096] buf;
    //uint chars = GetModuleFileNameExW(hProcess, hFile, buf.ptr, 4096);
    //return toUTF8(buf[0..chars]);
    return null;
}

// based on sample from MSDN https://msdn.microsoft.com/ru-ru/library/windows/desktop/aa366789(v=vs.85).aspx
string getFileNameFromHandle(HANDLE hFile) 
{
    string res = null;
    bool bSuccess = false;
    const int BUFSIZE = 4096;
    wchar pszFilename[BUFSIZE + 1];
    HANDLE hFileMap;

    // Get the file size.
    DWORD dwFileSizeHi = 0;
    DWORD dwFileSizeLo = GetFileSize(hFile, &dwFileSizeHi); 

    if( dwFileSizeLo == 0 && dwFileSizeHi == 0 ) {
       return null;
    }

    // Create a file mapping object.
    hFileMap = CreateFileMapping(hFile, 
                                 null, 
                    PAGE_READONLY,
                    0, 
                    1,
                                 null);

    if (hFileMap) {
        // Create a file mapping to get the file name.
        void* pMem = MapViewOfFile(hFileMap, FILE_MAP_READ, 0, 0, 1);

        if (pMem) {
            if (win32.psapi.GetMappedFileNameW(GetCurrentProcess(), 
                                 pMem,
                                 pszFilename.ptr,
                                 MAX_PATH)) 
            {

                // Translate path with device name to drive letters.
                TCHAR szTemp[BUFSIZE];
                szTemp[0] = '\0';

                size_t uFilenameLen = 0;
                for (int i = 0; i < MAX_PATH && pszFilename[i]; i++)
                    uFilenameLen++;

                if (GetLogicalDriveStrings(BUFSIZE-1, szTemp.ptr)) {
                    wchar szName[MAX_PATH];
                    wchar szDrive[3] = [' ', ':', 0];
                    bool bFound = false;
                    wchar* p = szTemp.ptr;

                    do {
                        // Copy the drive letter to the template string
                        szDrive[0] = *p;

                        // Look up each device name
                        if (QueryDosDevice(szDrive.ptr, szName.ptr, MAX_PATH)) {
                            size_t uNameLen = 0;
                            for (int i = 0; i < MAX_PATH && szName[i]; i++)
                                uNameLen++;
                            //_tcslen(szName);

                            if (uNameLen < MAX_PATH) {
                                bFound = false; //_tcsnicmp(pszFilename, szName, uNameLen) == 0
                                     //&& *(pszFilename + uNameLen) == _T('\\');
                                for (int i = 0; pszFilename[i] && i <= uNameLen; i++) {
                                    wchar c1 = pszFilename[i];
                                    wchar c2 = szName[i];
                                    if (c1 >= 'a' && c1 <= 'z') 
                                        c1 = cast(wchar)(c1 - 'a' + 'A');
                                    if (c2 >= 'a' && c2 <= 'z') 
                                        c2 = cast(wchar)(c2 - 'a' + 'A');
                                    if (c1 != c2) {
                                        if (c1 == '\\' && c2 == 0)
                                            bFound = true;
                                        break;
                                    }
                                }

                                if (bFound) {
                                    // Reconstruct pszFilename using szTempFile
                                    // Replace device path with DOS path
                                    res = toUTF8(szDrive[0..2] ~ pszFilename[uNameLen .. uFilenameLen]);
                                }
                            }
                        }

                        // Go to the next NULL character.
                        while (*p++) {
                        }
                    } while (!bFound && *p); // end of string
                }
            }
            UnmapViewOfFile(pMem);
        } 

        CloseHandle(hFileMap);
    }
    return res;
}

class WinDebugger : Thread {
    string _exefile;
    string _args;

    DllInfo[] _dlls;
    ProcessInfo[] _processes;

    this(string exefile, string args) {
        super(&run);
        _exefile = exefile;
        _args = args;
    }

    private void run() {
        Log.i("Debugger thread started");
        if (startDebugging())
            enterDebugLoop();
        Log.i("Debugger thread finished");
        _finished = true;
    }

    private shared bool _finished;
    STARTUPINFOW _si; 
    PROCESS_INFORMATION _pi;

    bool startDebugging() {

        Log.i("starting debug for '" ~ _exefile ~ "' args: " ~ _args);

        _stopRequested = false;
        _si = STARTUPINFOW.init;
        _si.cb = _si.sizeof;
        _pi = PROCESS_INFORMATION.init;

        string cmdline = "\"" ~ _exefile ~ "\"";
        if (_args.length > 0)
            cmdline = cmdline ~ " " ~ _args;
        wchar[] exefilew = cast(wchar[])toUTF16(_exefile);
        exefilew ~= cast(dchar)0;
        wchar[] cmdlinew = cast(wchar[])toUTF16(cmdline);
        cmdlinew ~= cast(dchar)0;
        if (!CreateProcessW(cast(const wchar*)exefilew.ptr, 
                            cmdlinew.ptr, 
                            cast(SECURITY_ATTRIBUTES*)NULL, cast(SECURITY_ATTRIBUTES*)NULL, 
                            FALSE, 
                            DEBUG_ONLY_THIS_PROCESS, 
                            NULL, 
                            cast(const wchar*)NULL, &_si, &_pi)) {
            return false;
        }
        Log.i("Executable '" ~ _exefile ~ "' started successfully");
        return true;
    }

    uint onCreateThreadDebugEvent(ref DEBUG_EVENT debug_event) {
        Log.d("onCreateThreadDebugEvent");
        return DBG_CONTINUE;
    }

    uint onCreateProcessDebugEvent(ref DEBUG_EVENT debug_event) {
        ProcessInfo pi = new ProcessInfo(debug_event);
        _processes ~= pi;
        Log.d("onCreateProcessDebugEvent " ~ pi.imageFileName ~ " debugInfoSize=" ~ format("%d", pi.debugInfoSize));
        return DBG_CONTINUE;
    }

    uint onExitThreadDebugEvent(ref DEBUG_EVENT debug_event) {
        Log.d("onExitThreadDebugEvent");
        return DBG_CONTINUE;
    }

    uint onExitProcessDebugEvent(ref DEBUG_EVENT debug_event) {
        Log.d("onExitProcessDebugEvent");
        return DBG_CONTINUE;
    }
    ProcessInfo findProcess(uint id) {
        foreach(p; _processes) {
            if (p.processId == id)
                return p;
        }
        return null;
    }

    uint onLoadDllDebugEvent(ref DEBUG_EVENT debug_event) {
        ProcessInfo pi = findProcess(debug_event.dwProcessId);
        if (pi !is null) {
            DllInfo dll = new DllInfo(pi, debug_event);
            _dlls ~= dll;
            Log.d("onLoadDllDebugEvent " ~ dll.imageFileName ~ " debugInfoSize=" ~ format("%d", dll.debugInfoSize));
        } else {
            Log.d("onLoadDllDebugEvent : process not found");
        }
        return DBG_CONTINUE;
    }
    uint onUnloadDllDebugEvent(ref DEBUG_EVENT debug_event) {
        Log.d("onUnloadDllDebugEvent");
        return DBG_CONTINUE;
    }
    uint onOutputDebugStringEvent(ref DEBUG_EVENT debug_event) {
        Log.d("onOutputDebugStringEvent");
        return DBG_CONTINUE;
    }
    uint onRipEvent(ref DEBUG_EVENT debug_event) {
        Log.d("onRipEvent");
        return DBG_TERMINATE_PROCESS;
    }

    void processDebugEvent(ref DEBUG_EVENT debug_event) {
        switch (debug_event.dwDebugEventCode)
        { 
            case EXCEPTION_DEBUG_EVENT:
                // Process the exception code. When handling 
                // exceptions, remember to set the continuation 
                // status parameter (dwContinueStatus). This value 
                // is used by the ContinueDebugEvent function. 

                switch(debug_event.Exception.ExceptionRecord.ExceptionCode)
                { 
                    case EXCEPTION_ACCESS_VIOLATION: 
                        // First chance: Pass this on to the system. 
                        // Last chance: Display an appropriate error. 
                        break;

                    case EXCEPTION_BREAKPOINT: 
                        // First chance: Display the current 
                        // instruction and register values. 
                        break;

                    case EXCEPTION_DATATYPE_MISALIGNMENT: 
                        // First chance: Pass this on to the system. 
                        // Last chance: Display an appropriate error. 
                        break;

                    case EXCEPTION_SINGLE_STEP: 
                        // First chance: Update the display of the 
                        // current instruction and register values. 
                        break;

                    case DBG_CONTROL_C: 
                        // First chance: Pass this on to the system. 
                        // Last chance: Display an appropriate error. 
                        break;

                    default:
                        // Handle other exceptions. 
                        break;
                } 

                break;

            case CREATE_THREAD_DEBUG_EVENT: 
                // As needed, examine or change the thread's registers 
                // with the GetThreadContext and SetThreadContext functions; 
                // and suspend and resume thread execution with the 
                // SuspendThread and ResumeThread functions. 

                _continueStatus = onCreateThreadDebugEvent(debug_event);
                break;

            case CREATE_PROCESS_DEBUG_EVENT: 
                // As needed, examine or change the registers of the
                // process's initial thread with the GetThreadContext and
                // SetThreadContext functions; read from and write to the
                // process's virtual memory with the ReadProcessMemory and
                // WriteProcessMemory functions; and suspend and resume
                // thread execution with the SuspendThread and ResumeThread
                // functions. Be sure to close the handle to the process image
                // file with CloseHandle.

                _continueStatus = onCreateProcessDebugEvent(debug_event);
                break;

            case EXIT_THREAD_DEBUG_EVENT: 
                // Display the thread's exit code. 

                _continueStatus = onExitThreadDebugEvent(debug_event);
                break;

            case EXIT_PROCESS_DEBUG_EVENT: 
                // Display the process's exit code. 

                _continueStatus = onExitProcessDebugEvent(debug_event);
                break;

            case LOAD_DLL_DEBUG_EVENT: 
                // Read the debugging information included in the newly 
                // loaded DLL. Be sure to close the handle to the loaded DLL 
                // with CloseHandle.

                _continueStatus = onLoadDllDebugEvent(debug_event);
                break;

            case UNLOAD_DLL_DEBUG_EVENT: 
                // Display a message that the DLL has been unloaded. 

                _continueStatus = onUnloadDllDebugEvent(debug_event);
                break;

            case OUTPUT_DEBUG_STRING_EVENT: 
                // Display the output debugging string. 

                _continueStatus = onOutputDebugStringEvent(debug_event);
                break;

            case RIP_EVENT:
                _continueStatus = onRipEvent(debug_event);
                break;
            default:
                // UNKNOWN EVENT
                break;
        } 
    }
    
    uint _continueStatus;
    bool _stopRequested;

    bool enterDebugLoop() {
        Log.i("entering debug loop");
        _continueStatus = DBG_CONTINUE;
        DEBUG_EVENT debug_event;
        debug_event = DEBUG_EVENT.init;

        for(;;)
        {
            if (!WaitForDebugEvent(&debug_event, INFINITE)) {
                uint err = GetLastError();
                Log.e("WaitForDebugEvent returned false. Error=" ~ format("%08x", err));
                return false;
            }
            //Log.i("processDebugEvent");
            processDebugEvent(debug_event);
            if (_continueStatus == DBG_TERMINATE_PROCESS)
                break;
            ContinueDebugEvent(debug_event.dwProcessId,
                               debug_event.dwThreadId,
                               _continueStatus);
        }
        Log.i("exiting debug loop");
        return true;
    }
}
