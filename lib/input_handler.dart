// This file contains the input handler for processing user input.

/// Processes user input to determine if it's a list item or a log entry.
///
/// Takes a string [input] as an argument and returns a string indicating
/// whether the input is classified as a "List Item" or a "Log Entry".
///
/// If the input string contains the word "add" (case-insensitive), it's
/// considered a "List Item". Otherwise, it's classified as a "Log Entry".
String processInput(String input) {
  if (input.toLowerCase().contains("add")) {
    return "List Item";
  } else {
    return "Log Entry";
  }
}