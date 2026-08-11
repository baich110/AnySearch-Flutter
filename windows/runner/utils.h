#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

std::string CreateAndAttachConsole();
void DispatchToProtocolCenter(HWND window);
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_