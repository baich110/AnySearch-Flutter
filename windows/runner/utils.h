#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console attachment and displays the console window.
// Returns an empty string if the console was successfully attached.
std::string CreateAndAttachConsole();

// Forwards a command to the existing instance of the app, if any.
void DispatchToProtocolCenter(HWND window);

// Takes a null-terminated wide string and returns a UTF-8 encoded string.
std::string WideToUtf8(const wchar_t* source);

// Returns the command line arguments as UTF-8 strings.
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_