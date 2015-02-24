module ddebug.windows.mago;
version(USE_MAGO):

import dlangui.core.logger;
//import core.stdc.stdio;
//import core.stdc.stdlib;
import win32.windows;
import win32.objbase;
import win32.oaidl;
import win32.wtypes;

const GUID CLSID_MAGO = {0xE348A53A, 0x470A, 0x4A70, [0x9B, 0x55, 0x1E, 0x02, 0xF3, 0x52, 0x79, 0x0D]};
const GUID IID_MAGO_NATIVE_ENGINE = {0x97348AC0, 0x2B6B, 0x4B99, [0xA2, 0x45, 0x4C, 0x7E, 0x2C, 0x09, 0xD4, 0x03]};
const GUID IID_IDebugEngine2 = {0xba105b52, 0x12f1, 0x4038, [0xae, 0x64, 0xd9, 0x57, 0x85, 0x87, 0x4c, 0x47]};

interface IEnumDebugPrograms2 : IUnknown {
}

interface IDebugProgram2 : IUnknown {
}

interface IDebugProgramNode2 : IUnknown {
}

interface IDebugEventCallback2 : IUnknown {
}

interface IDebugBreakpointRequest2 : IUnknown {
}

interface IDebugPendingBreakpoint2 : IUnknown {
}

interface IDebugEvent2 : IUnknown {
}

struct EXCEPTION_INFO {
}

alias ATTACH_REASON = uint;

interface IDebugEngine2 : IUnknown {
//extern(Windows):
    HRESULT EnumPrograms(IEnumDebugPrograms2 ** p);
    HRESULT Attach( IDebugProgram2 **rgpPrograms,
                    IDebugProgramNode2 **rgpProgramNodes,
                    DWORD celtPrograms,
                    IDebugEventCallback2 *pCallback,
                    ATTACH_REASON dwReason);

    HRESULT CreatePendingBreakpoint(IDebugBreakpointRequest2 *pBPRequest,
                                    IDebugPendingBreakpoint2 **ppPendingBP);

    HRESULT SetException(EXCEPTION_INFO *pException);

    HRESULT RemoveSetException( EXCEPTION_INFO *pException);

    HRESULT RemoveAllSetExceptions(REFGUID guidType);

    HRESULT GetEngineId(GUID *pguidEngine);

    HRESULT DestroyProgram(IDebugProgram2 *pProgram);

    HRESULT ContinueFromSynchronousEvent(IDebugEvent2 *pEvent);

    HRESULT SetLocale(WORD wLangID);

    HRESULT SetRegistryRoot(LPCOLESTR pszRegistryRoot);

    HRESULT SetMetric(LPCOLESTR pszMetric, VARIANT varValue);

    HRESULT CauseBreak();
}

void testMago() {
    HRESULT hr;
    IUnknown* piUnknown;
    IDebugEngine2 debugEngine = null;
    hr=CoInitialize(null);              // Initialize OLE
    if (FAILED(hr)) {
        Log.e("OLE 2 failed to initialize");
        return;
    }
    //hr = CoCreateInstance(&CLSID_MAGO, null, CLSCTX_ALL, &IID_IDebugEngine2, cast(void**)&piUnknown);
    hr = CoCreateInstance(&IID_MAGO_NATIVE_ENGINE, //CLSID_MAGO, 
                          null, 
                          CLSCTX_INPROC, //CLSCTX_ALL, 
                          &IID_IDebugEngine2, //IID_MAGO_NATIVE_ENGINE, 
                          cast(void**)&debugEngine); //piUnknown);
    if (debugEngine) {
        Log.d("Debug interface is not null");
    }
    if (FAILED(hr) || !debugEngine) {
        Log.e("Failed to create MAGO interface instance %x", hr);
        return;
    }

    Log.d("Debug interface initialized ok");
    GUID eid;
    debugEngine.GetEngineId(&eid);
    Log.d("Engine id: ", eid);
}
