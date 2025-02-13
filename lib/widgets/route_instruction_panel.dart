import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:snownavi/global_constants.dart';
import '../route_engine.dart' as re; // Import your Route and RouteStep models
import '../timer_flag.dart'; // Import TimerFlag class

class RouteInstructionPanel extends StatelessWidget {
  final re.Route route;
  final VoidCallback onClose; // Callback to close the panel

  const RouteInstructionPanel({
    Key? key,
    required this.route,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4, // Initial size of the panel
      minChildSize: 0.2, // Minimum size
      maxChildSize: 0.8, // Maximum expandable size
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              _buildHeader(),

              // Scrollable list of route steps
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: route.steps.length,
                  itemBuilder: (context, index) {
                    final step = route.steps[index];
                    return _buildStepItem(step, index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the panel header showing route summary and close button
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Route Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                "${(route.distance / 1000).toStringAsFixed(2)} km • ${(route.duration / 60).toStringAsFixed(0)} min",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  /// Builds each route step in the list
  Widget _buildStepItem(re.RouteStep step, int index) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          (index + 1).toString(),
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      title: Text(
        step.name.isNotEmpty ? step.name : "Unnamed Path",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        "${step.distance.toStringAsFixed(0)} m • ${step.duration.toStringAsFixed(0)} sec",
      ),
      trailing: Icon(Icons.directions_walk, color: Colors.blue),
    );
  }
}

class FloatingRouteInstructionPanel extends StatefulWidget {
  final re.Route route;
  final VoidCallback onClose;
  final double panelWidth; // Match search box width
  final TimerFlag timerFlag; // Pass TimerFlag instance
  final MapboxMapController mapController; // Pass Mapbox controller

  const FloatingRouteInstructionPanel({
    Key? key,
    required this.route,
    required this.onClose,
    required this.panelWidth,
    required this.timerFlag,
    required this.mapController,
  }) : super(key: key);

  @override
  _FloatingRouteInstructionPanelState createState() => _FloatingRouteInstructionPanelState();
}

class _FloatingRouteInstructionPanelState extends State<FloatingRouteInstructionPanel> {
  bool _isExpanded = true; // Start expanded by default
  double _collapsedHeight = 75;
  double _expandedHeight = 360;
  Symbol? _currentStepMarker; // Store the last added marker
  List<Symbol> _stepMarkersToRemove = []; // Buffer list for step markers

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80, // **Placed below the search box**
      left: 20, // Align with search box
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Prevents touch events from passing to Mapbox
        onVerticalDragUpdate: (details) {
          print("drag update with: $details");
          widget.timerFlag.flag = true; // Activate TimerFlag on drag
          setState(() {
            _isExpanded = details.primaryDelta! > 0; // Expand downward
          });
        },
        onVerticalDragStart: (details) {
          print("drag start with: $details");
          widget.timerFlag.flag = true; // Activate TimerFlag when scroll starts
        },
        onVerticalDragEnd: (details) {
          print("drag end with: $details");
          widget.timerFlag.flag = true; // Activate TimerFlag when scroll ends
        },
        onTap: () {
          widget.timerFlag.flag = true; // Activate TimerFlag on tap
        },
        onPanUpdate: (details) {
          print("drag on pan with: $details");
          widget.timerFlag.flag = true; // Activate TimerFlag on any pan movement
        },
        child: AnimatedContainer(
          width: widget.panelWidth, // Match search box width
          duration: Duration(milliseconds: 300),
          height: _isExpanded ? _expandedHeight : _collapsedHeight, // Expand downward
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(child: _buildStepList()), // Always expanded
            ],
          ),
        ),
      ),
    );
  }

  /// **Builds the panel header with summary and close button**
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Route Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              Text(
                "${(widget.route.distance / 1000).toStringAsFixed(2)} km • ${(widget.route.duration / 60).toStringAsFixed(0)} min",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                onPressed: () {
                  widget.timerFlag.flag = true; // Activate TimerFlag on button press
                  setState(() {
                    _isExpanded = !_isExpanded; // Toggle expansion
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  widget.timerFlag.flag = true;
                  widget.onClose();
                }
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// **Builds the list of route steps**
  Widget _buildStepList() {
    return ListView.builder(
      itemCount: widget.route.steps.length,
      itemBuilder: (context, index) {
        final step = widget.route.steps[index];
        return _buildStepItem(step, index);
      },
    );
  }

  IconData _getManeuverIcon(String type, String? modifier) {
    switch (type) {
      case 'depart':
        return Icons.straight; // Start of the route
      case 'arrive':
        return Icons.flag; // End of the route
      default:
        return _getTurnIcon(modifier);  // Use modifier for turn direction
    }
  }

  /// **Helper method to determine turn icon based on modifier**
  IconData _getTurnIcon(String? modifier) {
    switch (modifier) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'slight left':
        return Icons.turn_slight_left;
      case 'slight right':
        return Icons.turn_slight_right;
      case 'sharp left':
        return Icons.turn_sharp_left;
      case 'sharp right':
        return Icons.turn_sharp_right;
      case 'uturn':
        return Icons.u_turn_left; // U-turn maneuver
      default:
        return Icons.straight; // Default icon
    }
  }

  String _formatDuration(double seconds) {
    int minutes = (seconds ~/ 60); // Get full minutes
    int remainingSeconds = (seconds % 60).round(); // Get remaining seconds

    if (minutes > 0) {
      return "$minutes min ${remainingSeconds}s"; // Example: "5 min 30s"
    } else {
      return "$remainingSeconds sec"; // Example: "45 sec"
    }
  }

  Future<void> _addStepMarker(List<double> location) async{
    // Add a marker at the step location
    _currentStepMarker = await widget.mapController.addSymbol(
      SymbolOptions(
        geometry: LatLng(location[1], location[0]), // Ensure correct lat-lng order
        iconImage: GlobalConstants.routeHighlightImageName, // Custom marker name
        iconSize: 1.5, // Adjust size
      ),
    );

    print("Added step marker ${_currentStepMarker?.id} at: ${location[1]}, ${location[0]}");
  }

  Future<void> _removeStepMarker() async {
    while (_stepMarkersToRemove.isNotEmpty) {
      Symbol marker = _stepMarkersToRemove.removeAt(0); // Get and remove the first marker
      print("Removing step marker ${marker.id}");

      await widget.mapController.removeSymbol(marker);
    }
  }

  /// **Builds each step item**
  Widget _buildStepItem(re.RouteStep step, int index) {
    return MouseRegion(
      onEnter: (_) {
        print("Hovering over step $index");
        _addStepMarker(step.maneuver.location); // Add marker on hover
      },
      onExit: (_) {
        print("Exiting step $index");
        _stepMarkersToRemove.add(_currentStepMarker!); // Buffer for removal
        _removeStepMarker(); // Remove marker when exiting
      },
      child: ListTile(
        onTap: () {
          widget.timerFlag.flag = true; // Activate TimerFlag when tapping a step
        },
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text((index + 1).toString(), style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        title: Text(step.name.isNotEmpty ? step.name : "Unnamed Piste", style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${step.distance.toStringAsFixed(0)} m • ${_formatDuration(step.duration)}"),
        trailing: Icon(_getManeuverIcon(step.maneuver.type, step.maneuver.modifier), color: Theme.of(context).primaryColor),
      ),
    );
  }
}
