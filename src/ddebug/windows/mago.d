module ddebug.windows.mago;
version(Windows):
version(USE_MAGO):

import ddebug.windows.msdbg;
import dlangui.core.logger;
import core.atomic;
import std.string;

//const GUID CLSID_MAGO = {0xE348A53A, 0x470A, 0x4A70, [0x9B, 0x55, 0x1E, 0x02, 0xF3, 0x52, 0x79, 0x0D]};
const GUID IID_MAGO_NATIVE_ENGINE = {0x97348AC0, 0x2B6B, 0x4B99, [0xA2, 0x45, 0x4C, 0x7E, 0x2C, 0x09, 0xD4, 0x03]};

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

void testMago() {
    HRESULT hr;
    IUnknown* piUnknown;
    IDebugEngine2 debugEngine = null;
    IDebugEngineLaunch2 debugEngineLaunch = null;
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
        Log.e("Failed to create MAGO interface instance ", hr);
        return;
    }

    Log.d("Debug interface initialized ok");
    GUID eid;
    debugEngine.GetEngineId(&eid);
    Log.d("Engine id: ", eid);

    hr = debugEngine.QueryInterface(cast(GUID*)&IID_IDebugEngineLaunch2, cast(void**)&debugEngineLaunch);
    if (FAILED(hr) || !debugEngineLaunch) {
        Log.e("Failed to get IID_IDebugEngineLaunch2 interface ", hr);
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


    hr = debugEngineLaunch.LaunchSuspended ( 
                             null,
                             null,
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
        Log.e("Failed to run process ", format("%08x", hr));
        return;
    }
    Log.d("LaunchSuspended executed ok");
}
