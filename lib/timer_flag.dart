import 'dart:async';

class TimerFlag {
  bool _flag = false;
  Timer? _timer;

  // Setter for the flag property
  set flag(bool value) {
    setFlag(value); // Call the existing setFlag method
  }

  // Getter for the flag property (if needed)
  bool get flag => _flag;

  // Function to set the flag and start the timer
  void setFlag(bool value, {int durationInMilliSeconds = 500}) {
    // Set the flag
    _flag = value;
    
    // If the value is true, start a timer to reset the flag
    if (_flag) {
      _startTimer(durationInMilliSeconds);
    } else {
      _cancelTimer(); // If it's set to false manually, cancel any running timer
    }
  }

  // Start the timer
  void _startTimer(int durationInMilliSeconds) {
    _cancelTimer(); // Cancel any existing timer first
    _timer = Timer(Duration(milliseconds: durationInMilliSeconds), () {
      _flag = false;
      print("flag has been reset to false after $durationInMilliSeconds ms");
    });
  }

  // Cancel the timer if needed
  void _cancelTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
  }

  // Optionally, you can also provide a method to manually stop the timer
  void stopTimer() {
    _cancelTimer();
    print("Timer stopped manually");
  }
}
