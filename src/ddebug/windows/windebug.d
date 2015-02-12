// just an attempt to implement D debugger for win32
module ddebug.windows.windebug;

import win32.windows;

import std.utf;

version(Windows):


class WinDebugger {
    this() {
    }

    STARTUPINFOW _si; 
    PROCESS_INFORMATION _pi;

    bool startDebugging(string exefile, string args) {
        _stopRequested = false;
        _si = STARTUPINFOW.init;
        _si.cb = _si.sizeof;
        _pi = PROCESS_INFORMATION.init;

        string cmdline = "\"" ~ exefile ~ "\"";
        if (args.length > 0)
            cmdline = cmdline ~ " " ~ args;
        wchar[] exefilew = cast(wchar[])toUTF16(exefile);
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
        return true;
    }

    uint onCreateThreadDebugEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onCreateProcessDebugEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onExitThreadDebugEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onExitProcessDebugEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onLoadDllDebugEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onUnloadDllDebugEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onOutputDebugStringEvent(ref DEBUG_EVENT debug_event) {
        return DBG_CONTINUE;
    }
    uint onRipEvent(ref DEBUG_EVENT debug_event) {
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
        _continueStatus = DBG_CONTINUE;
        DEBUG_EVENT debug_event;
        for(;;)
        {
            if (!WaitForDebugEvent(&debug_event, INFINITE))
                return false;
            processDebugEvent(debug_event);
            ContinueDebugEvent(debug_event.dwProcessId,
                               debug_event.dwThreadId,
                               _continueStatus);
        }
    }
}
