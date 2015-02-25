module ddebug.windows.mago;
version(Windows):
version(USE_MAGO):

import ddebug.windows.msdbg;
import dlangui.core.logger;

//const GUID CLSID_MAGO = {0xE348A53A, 0x470A, 0x4A70, [0x9B, 0x55, 0x1E, 0x02, 0xF3, 0x52, 0x79, 0x0D]};
const GUID IID_MAGO_NATIVE_ENGINE = {0x97348AC0, 0x2B6B, 0x4B99, [0xA2, 0x45, 0x4C, 0x7E, 0x2C, 0x09, 0xD4, 0x03]};


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
