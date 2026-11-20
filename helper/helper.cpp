// Sits next to the Godot process: moves its window behind the desktop icons,
// reports full-screen apps over UDP, and repaints the wallpaper when Godot exits.
#include <winsock2.h>
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <cstdlib>

static BOOL CALLBACK FindWorker(HWND top, LPARAM out) {
    if (FindWindowExW(top, nullptr, L"SHELLDLL_DefView", nullptr)) {
        HWND next = FindWindowExW(nullptr, top, L"WorkerW", nullptr);
        if (next) *reinterpret_cast<HWND*>(out) = next;
    }
    return TRUE;
}

static HWND DesktopLayer() {
    HWND progman = FindWindowW(L"Progman", nullptr);
    SendMessageTimeoutW(progman, 0x052C, 0, 0, SMTO_NORMAL, 1000, nullptr);
    HWND worker = nullptr;
    EnumWindows(FindWorker, reinterpret_cast<LPARAM>(&worker));
    if (!worker) worker = FindWindowExW(progman, nullptr, L"WorkerW", nullptr); // 24H2 layout
    return worker;
}

static bool CoversPrimary() {
    QUERY_USER_NOTIFICATION_STATE state;
    if (SUCCEEDED(SHQueryUserNotificationState(&state)) &&
        (state == QUNS_RUNNING_D3D_FULL_SCREEN || state == QUNS_PRESENTATION_MODE))
        return true;
    // The root also catches our own window, which sits inside the desktop layer.
    HWND fg = GetAncestor(GetForegroundWindow(), GA_ROOT);
    if (!fg) return false;
    wchar_t cls[32] = {};
    GetClassNameW(fg, cls, 32);
    if (!lstrcmpW(cls, L"Progman") || !lstrcmpW(cls, L"WorkerW")) return false;
    RECT r;
    GetWindowRect(fg, &r);
    return r.left <= 0 && r.top <= 0 &&
           r.right >= GetSystemMetrics(SM_CXSCREEN) && r.bottom >= GetSystemMetrics(SM_CYSCREEN);
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    int argc = 0;
    wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argc < 3) return 1;
    HWND win = reinterpret_cast<HWND>(_wcstoui64(argv[1], nullptr, 10));
    DWORD pid = static_cast<DWORD>(wcstoul(argv[2], nullptr, 10));
    SetProcessDPIAware();
    HANDLE proc = OpenProcess(SYNCHRONIZE, FALSE, pid);
    HWND layer = DesktopLayer();
    if (!proc || !layer || !IsWindow(win)) return 2;

    LONG style = GetWindowLongW(win, GWL_STYLE);
    SetWindowLongW(win, GWL_STYLE, (style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME)) | WS_CHILD);
    SetParent(win, layer);
    int x = -GetSystemMetrics(SM_XVIRTUALSCREEN);
    int y = -GetSystemMetrics(SM_YVIRTUALSCREEN);
    SetWindowPos(win, HWND_TOP, x, y, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN),
                 SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_FRAMECHANGED);

    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);
    SOCKET sock = socket(AF_INET, SOCK_DGRAM, 0);
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(47631);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    // Pause only after the screen has stayed covered for a while; resume at once.
    // Alt-tabbing or a brief fullscreen flash must not stop and restart rendering.
    int sent = -1, streak = 0;
    while (WaitForSingleObject(proc, 250) == WAIT_TIMEOUT) {
        streak = CoversPrimary() ? streak + 1 : 0;
        int covered = streak >= 8 ? 1 : 0; // 2 s
        if (covered != sent) {
            const char* msg = covered ? "1" : "0";
            sendto(sock, msg, 1, 0, reinterpret_cast<sockaddr*>(&addr), sizeof addr);
            sent = covered;
        }
    }

    // Re-applying the current path repaints the normal wallpaper; flags 0 saves nothing.
    wchar_t path[MAX_PATH] = {};
    SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, path, 0);
    SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, path, 0);
    return 0;
}
