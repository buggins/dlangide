module ddebug.windows.mago;
version(Windows):
version(USE_MAGO):

import ddebug.windows.msdbg;
import dlangui.core.logger;
import core.atomic;
import std.string;

//const GUID CLSID_MAGO = {0xE348A53A, 0x470A, 0x4A70, [0x9B, 0x55, 0x1E, 0x02, 0xF3, 0x52, 0x79, 0x0D]};
const GUID IID_MAGO_NATIVE_ENGINE = {0x97348AC0, 0x2B6B, 0x4B99, [0xA2, 0x45, 0x4C, 0x7E, 0x2C, 0x09, 0xD4, 0x03]};
//const GUID CLSID_PORT_SUPPLIER =    {0x3484EFB2, 0x0A52, 0x4EB2, [0x86, 0x9C, 0x1F, 0x7E, 0x66, 0x8E, 0x1B, 0x87]};
//const GUID CLSID_PORT_SUPPLIER =    {0x3B476D38, 0xA401, 0x11D2, [0xAA, 0xD4, 0x00, 0xC0, 0x4F, 0x99, 0x01, 0x71]}; //3B476D38-A401-11D2-AAD4-00C04F990171
const GUID CLSID_PORT_SUPPLIER =    {0x708C1ECA, 0xFF48, 0x11D2, [0x90, 0x4F, 0x00, 0xC0, 0x4F, 0xA3, 0x02, 0xA1]}; //{708C1ECA-FF48-11D2-904F-00C04FA302A1}
//const GUID CLSID_PORT_SUPPLIER =    {0xF561BF8D, 0xBFBA, 0x4FC6, [0xAE, 0xA7, 0x24, 0x45, 0xD0, 0xEA, 0xC1, 0xC5]};
//const GUID CLSID_PORT_SUPPLIER =    {0x708C1ECA, 0xFF48, 0x11D2, [0x90, 0x4F, 0x00, 0x04, 0xA3, 0x2, 0xA1]};

class ComObject : IUnknown
{
    extern (Windows):
    HRESULT QueryInterface(GUID* riid, void** ppv)
    {
        if (*riid == IID_IUnknown)
        {
            *ppv = cast(void*)cast(IUnknown)this;
            AddRef();
            return S_OK;
        }
        else
        {   *ppv = null;
            return E_NOINTERFACE;
        }
    }

    ULONG AddRef()
    {
        return atomicOp!"+="(*cast(shared)&count, 1);
    }

    ULONG Release()
    {
        LONG lRef = atomicOp!"-="(*cast(shared)&count, 1);
        if (lRef == 0)
        {
            // free object

            // If we delete this object, then the postinvariant called upon
            // return from Release() will fail.
            // Just let the GC reap it.
            //delete this;

            return 0;
        }
        return cast(ULONG)lRef;
    }

    LONG count = 0;             // object reference count
}

class DebugCallback : ComObject, IDebugEventCallback2 {

	override HRESULT Event(
            /+[in]+/ IDebugEngine2 pEngine,
            /+[in]+/ IDebugProcess2 pProcess,
            /+[in]+/ IDebugProgram2 pProgram,
            /+[in]+/ IDebugThread2 pThread,
            /+[in]+/ IDebugEvent2 pEvent,
            in IID* riidEvent,
            in DWORD dwAttrib) {
        //
        Log.d("debug event");
        return 0;
    }

}

string formatHResult(HRESULT hr) {
    switch(hr) {
        case S_OK: return "S_OK";
        case S_FALSE: return "S_FALSE";
        case E_NOTIMPL: return "E_NOTIMPL";
        case E_NOINTERFACE: return "E_NOINTERFACE";
        case E_FAIL: return "E_FAIL";
        case E_HANDLE: return "E_HANDLE";
        case 0x80040154: return "REGDB_E_CLASSNOTREG";
        default:
            return format("%08x", hr);
    }
}

IDebugPortSupplier2 createPortSupplier() {
    HRESULT hr;
    IDebugPortSupplier2 portSupplier = null;
    LPOLESTR str;
    StringFromCLSID(&CLSID_PORT_SUPPLIER, &str);
    hr = CoCreateInstance(&CLSID_PORT_SUPPLIER, //CLSID_MAGO, 
                            null, 
                            CLSCTX_INPROC, //CLSCTX_ALL, 
                            &IID_IDebugPortSupplier2, //IID_MAGO_NATIVE_ENGINE, 
                            cast(void**)&portSupplier); //piUnknown);
    if (FAILED(hr) || !portSupplier) {
        Log.e("Failed to create port supplier ", formatHResult(hr));
        return null;
    }
    Log.i("Port supplier is created");
    return portSupplier;
}

class DebugPortRequest : ComObject, IDebugPortRequest2 {
    static const wchar[] portName = "magoDebuggerPort\0";
	HRESULT GetPortName(/+[out]+/ BSTR* pbstrPortName) {
        pbstrPortName = cast(BSTR*)portName.ptr;
        return S_OK;
    }
}

void testMago() {
    HRESULT hr;
    IUnknown* piUnknown;
    IDebugEngine2 debugEngine = null;
    IDebugEngineLaunch2 debugEngineLaunch = null;
    hr=CoInitialize(null);              // Initialize OLE
    if (FAILED(hr)) {
        Log.e("OLE 2 failed to initialize", formatHResult(hr));
        return;
    }

    IDebugPortSupplier2 portSupplier = createPortSupplier();
    if (!portSupplier) {
        Log.e("Failed to create port supplier");
        return;
    }
    if (portSupplier.CanAddPort() != S_OK) {
        Log.e("Cannot add debug port ", portSupplier.CanAddPort());
        return;
    }
    IDebugPort2 debugPort = null;
    DebugPortRequest debugPortRequest = new DebugPortRequest();
	// Add a port
	hr = portSupplier.AddPort(
                    /+[in]+/ debugPortRequest,
                    /+[out]+/ &debugPort);
    if (FAILED(hr) || !debugPort) {
        Log.e("Failed to create debub port ", formatHResult(hr));
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
        Log.e("Failed to create MAGO interface instance ", formatHResult(hr));
        return;
    }

    Log.d("Debug interface initialized ok");
    GUID eid;
    debugEngine.GetEngineId(&eid);
    Log.d("Engine id: ", eid);

    hr = debugEngine.QueryInterface(cast(GUID*)&IID_IDebugEngineLaunch2, cast(void**)&debugEngineLaunch);
    if (FAILED(hr) || !debugEngineLaunch) {
        Log.e("Failed to get IID_IDebugEngineLaunch2 interface ", formatHResult(hr));
        return;
    }

    IDebugProcess2 process = null;
    DebugCallback callback = new DebugCallback();

    wchar[] exe = `D:\projects\d\dlangide\workspaces\tetris\bin\tetris.exe`w.dup;
    wchar[] args;
    wchar[] dir = `D:\projects\d\dlangide\workspaces\tetris\bin`w.dup;
    wchar[] envblock;
    wchar[] opts;
    exe ~= 0;
    args ~= 0;
    dir ~= 0;
    envblock ~= 0;
    opts ~= 0;

    IDebugPort2 port;
    hr = debugEngineLaunch.LaunchSuspended ( 
                             null,
                             port,
                             exe.ptr,//LPCOLESTR
                             args.ptr,
                             dir.ptr,
                             envblock.ptr,
                             opts.ptr,
                             LAUNCH_DEBUG, //LAUNCH_NODEBUG
                             0,
                             0,
                             0,
                             callback,
                             &process
                             );

    if (FAILED(hr) || !process) {
        Log.e("Failed to run process ", formatHResult(hr));
        return;
    }
    Log.d("LaunchSuspended executed ok");
}
