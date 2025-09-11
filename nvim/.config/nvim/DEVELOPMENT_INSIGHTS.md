# Development Insights & Best Practices

This document captures key learnings from code review and debugging sessions to improve future development work.

## Code Review Methodology

### Systematic Approach
1. **Create TODO Lists**: Break down complex tasks into specific, actionable items
2. **Prioritize by Severity**: Security → Critical Bugs → Performance → Maintainability
3. **Reference Line Numbers**: Always cite specific locations when identifying issues
4. **Apply Fixes Systematically**: Work through issues one by one with clear progress tracking

### Security-First Mindset
- **Path Traversal**: Simple `../` removal insufficient - use multiple passes and normalization
- **Command Injection**: Escape shell metacharacters comprehensively (`$`, `` ` ``, `\`, `"`, `'`, `;`, `&`, `|`)
- **File System Access**: Always validate file paths and check file existence before operations
- **Input Sanitization**: Validate and sanitize all user inputs before processing

## Performance Optimization Patterns

### Caching Strategies
- **Race Condition Protection**: Use mutex-like mechanisms for concurrent access
- **Incremental Updates**: Update only changed files instead of rebuilding entire cache
- **File System Optimization**: Cache file stats to avoid redundant system calls
- **TTL Implementation**: Use time-based cache invalidation for freshness

### Memory Management
- **Resource Cleanup**: Always provide cleanup functions with autocmd fallbacks
- **Buffer Management**: Properly delete buffers and close windows to prevent leaks
- **Error Handling**: Use `pcall` for operations that might fail

## Code Quality Standards

### Maintainability
- **Constants Over Magic Numbers**: Define named constants for better readability
- **Function Decomposition**: Break complex nested functions into smaller, focused helpers
- **Consistent Naming**: Use snake_case consistently throughout Lua code
- **Error Handling**: Standardize error reporting with centralized functions

### Reliability
- **Dynamic Configuration**: Avoid hardcoded values that break when environment changes
- **Graceful Degradation**: Provide fallbacks when primary functionality fails
- **Validation**: Check preconditions before operations
- **Resource Management**: Ensure proper cleanup in all code paths

## Debugging Strategies

### Effective Debugging
- **Temporary Logging**: Add debug output to identify issues, remove after fixing
- **Incremental Testing**: Test each fix before moving to next issue
- **Systematic Investigation**: Use debug output to trace execution flow
- **User Feedback**: Provide clear error messages and status updates

### Common Pitfalls
- **Cache Logic Errors**: Ensure cache updates preserve loaded data
- **Command Escaping**: Different contexts require different escaping strategies
- **File Path Issues**: Validate paths before file operations
- **Concurrent Access**: Protect shared resources from race conditions

## Tmux Integration Patterns

### Robust Pane Management
- **Dynamic Detection**: Find panes by title/name instead of hardcoded IDs
- **Command Escaping**: Use single quotes to prevent shell interpretation
- **Error Handling**: Provide fallbacks when tmux panes don't exist
- **State Management**: Track pane availability and connection status

### Command Execution
- **Empty Commands**: Handle empty strings specially (for Enter key simulation)
- **Shell Safety**: Prevent command injection through proper escaping
- **Error Reporting**: Provide clear feedback when commands fail

## Future Development Guidelines

### When Adding New Features
1. **Security Review**: Check for injection vulnerabilities and path traversal
2. **Performance Impact**: Consider caching and optimization opportunities
3. **Error Handling**: Implement comprehensive error reporting
4. **Resource Management**: Ensure proper cleanup and resource handling
5. **Testing**: Add debug output for initial testing, remove for production

### When Refactoring Existing Code
1. **Identify Duplication**: Look for repeated patterns that can be extracted
2. **Simplify Complex Functions**: Break down large functions into smaller ones
3. **Standardize Patterns**: Apply consistent error handling and naming conventions
4. **Optimize Performance**: Look for redundant operations and caching opportunities
5. **Improve Reliability**: Add validation and fallback mechanisms

This document should be updated with new insights from future development sessions.