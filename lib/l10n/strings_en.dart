import 'app_strings.dart';

/// English strings implementation
class StringsEn implements AppStrings {
  // General
  @override
  String get appName => 'SnowNavi';
  @override
  String get appTitle => 'Ultimate Ski Route Planner | SnowNavi';
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get close => 'Close';
  @override
  String get refresh => 'Refresh';
  @override
  String get loading => 'Loading...';
  @override
  String get error => 'Error';
  @override
  String get unknown => 'Unknown';
  @override
  String get confirm => 'Confirm';
  @override
  String get add => 'Add';
  @override
  String get followMeOnSocialMedia => 'Follow me on 小红书 @了不起的okboy';

  // Map related
  @override
  String get loadingMap => 'Loading Map...';
  @override
  String get filter => 'Filter';
  @override
  String get filterPistes => 'Filter Pistes';
  @override
  String get locateMe => 'Locate Me';
  @override
  String get share => 'Share';
  @override
  String get layers => 'Layers';
  @override
  String get mapLayers => 'Map Layers';
  @override
  String get openSnowMap => 'OpenSnowMap';
  @override
  String get openSnowMapDesc => 'Show global ski piste layer';
  @override
  String get searchPoi => 'Search POI';
  @override
  String get noResults => 'No results found';
  @override
  String get openPhoto => 'Open Photo';
  @override
  String get select => 'Select';

  // Difficulty levels
  @override
  String get difficultyNovice => 'Novice';
  @override
  String get difficultyEasy => 'Easy';
  @override
  String get difficultyIntermediate => 'Intermediate';
  @override
  String get difficultyAdvanced => 'Advanced';
  @override
  String get difficultyExpert => 'Expert';
  @override
  String get difficultyFreeride => 'Freeride';
  @override
  String getDifficultyName(String difficulty) {
    switch (difficulty) {
      case 'novice':
        return difficultyNovice;
      case 'easy':
        return difficultyEasy;
      case 'intermediate':
        return difficultyIntermediate;
      case 'advanced':
        return difficultyAdvanced;
      case 'expert':
        return difficultyExpert;
      case 'freeride':
        return difficultyFreeride;
      default:
        return difficulty;
    }
  }

  // 2D/3D toggle
  @override
  String get mode2D => '2D';
  @override
  String get mode3D => '3D';
  @override
  String headingLabel(String heading) => 'Heading: $heading';

  // Route planning
  @override
  String get routePlanning => 'Route Planning';
  @override
  String get origin => 'Start';
  @override
  String get destination => 'End';
  @override
  String get stopover => 'Waypoint';
  @override
  String stopoverN(int n) => 'Waypoint $n';
  @override
  String get addStopover => 'Add Waypoint';
  @override
  String get setAsOrigin => 'Set as Start';
  @override
  String get setAsDestination => 'Set as End';
  @override
  String get setAsStopover => 'Set as Waypoint';
  @override
  String get addAsStopover => 'Add Waypoint';
  @override
  String get route => 'Route';
  @override
  String get routeDetails => 'Route Details';
  @override
  String get searchOrigin => 'Search start';
  @override
  String get searchDestination => 'Search end';
  @override
  String searchStopoverN(int n) => 'Search waypoint $n';
  @override
  String get searchNewStopover => 'Search new waypoint';
  @override
  String get clickToSelect => 'Click to select';
  @override
  String clickToSelectLabel(String label) => 'Click to select $label';
  @override
  String originWithCoords(String coords) => 'Origin ($coords)';
  @override
  String destinationWithCoords(String coords) => 'Destination ($coords)';
  @override
  String stopoverWithCoords(int n, String coords) => 'Waypoint $n ($coords)';
  @override
  String get currentLocation => 'Current Location';
  @override
  String get fromPhoto => 'From Photo';
  @override
  String get searchPlace => 'Search places...';
  @override
  String get myLocation => 'My Location';
  @override
  String routeDistanceKm(double km) => '${km.toStringAsFixed(1)}km';
  @override
  String routeInfo(String distance, String duration) =>
      '$distance • $duration min';
  @override
  String routeSummary(double distanceKm, double durationMin) =>
      '${distanceKm.toStringAsFixed(2)} km • ${durationMin.toStringAsFixed(0)} min';
  @override
  String get unnamedPiste => 'Unnamed Piste';
  @override
  String stepInfo(String distance, String duration) => '$distance • $duration';
  @override
  String photoLocation(double lat, double lng) =>
      'Photo location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  @override
  String get noGpsDataInPhoto =>
      'Cannot read location from photo, please try another photo';
  @override
  String stepDurationMinSec(int minutes, int seconds) =>
      '$minutes min ${seconds}s';
  @override
  String stepDurationSec(int seconds) => '$seconds sec';

  // Team related
  @override
  String get teamSkiing => 'Team Skiing';
  @override
  String get yourNickname => 'Your Nickname';
  @override
  String get createNewTeam => 'Create New Team';
  @override
  String get teamName => 'Team Name';
  @override
  String get teamNameHint => 'e.g. Weekend Ski Crew';
  @override
  String get createTeam => 'Create Team';
  @override
  String get joinExistingTeam => 'Join Existing Team';
  @override
  String get teamCode => 'Team Code';
  @override
  String get teamCodeHint => 'Enter 6-digit team code';
  @override
  String get joinTeam => 'Join Team';
  @override
  String get pleaseEnterNickname => 'Please enter nickname';
  @override
  String get pleaseEnterTeamName => 'Please enter team name';
  @override
  String get pleaseEnterTeamCode => 'Please enter team code';
  @override
  String get createFailed => 'Creation failed';
  @override
  String get joinFailed => 'Join failed';
  @override
  String get noPermissionCreateTeam =>
      'Permission denied: Only super admins can create teams';
  @override
  String get adminVerification => 'Admin Verification';
  @override
  String get adminVerificationDesc =>
      'Creating a team requires admin privileges. Please enter your admin email:';
  @override
  String get adminEmail => 'Admin Email';
  @override
  String get adminEmailHint => 'admin@example.com';
  @override
  String get verify => 'Verify';
  @override
  String get permissionDenied =>
      'Permission denied: Only super admins can create teams';
  @override
  String teamMemberCount(int current, int max) => '$current/$max members';
  @override
  String teamCodeLabel(String code) => 'Team Code: $code';
  @override
  String get inviteLink => 'Invite Link';
  @override
  String get linkCopied => 'Link copied';
  @override
  String get meetingPoints => 'Meeting Points';
  @override
  String get shareMyLocation => 'Share My Location';
  @override
  String get shareMyLocationDesc => 'Let teammates see your real-time location';
  @override
  String get showMeetingPoints => 'Show Meeting Points';
  @override
  String get showMeetingPointsDesc => 'Show all meeting points on the map';
  @override
  String get teamMembers => 'Team Members';
  @override
  String get refreshMemberLocation => 'Refresh member locations';
  @override
  String get refreshed => 'Refreshed';
  @override
  String maxMembersLabel(int max) => 'Max members: $max';
  @override
  String get leaveTeam => 'Leave Team';
  @override
  String get leaveTeamConfirm => 'Are you sure you want to leave this team?';
  @override
  String get me => 'Me';
  @override
  String get sharingLocation => 'Sharing location';
  @override
  String get checkedInToday => 'Checked in today';
  @override
  String get notCheckedIn => 'Not checked in';
  @override
  String get changeNickname => 'Change Nickname';
  @override
  String get newNickname => 'New Nickname';
  @override
  String get newNicknameHint => 'Enter new nickname';
  @override
  String get nicknameUpdated => 'Nickname updated';
  @override
  String get updateFailed => 'Update failed, please try again';
  @override
  String get removeMember => 'Remove Member';
  @override
  String removeMemberConfirm(String name) =>
      'Are you sure you want to remove $name?';
  @override
  String get setMaxMembers => 'Set Max Members';
  @override
  String maxMembersValue(int count) => '$count members';
  @override
  String get maxMembersFeatureNotAvailable =>
      'Max members feature is not available yet';
  @override
  String get operationFailed => 'Operation failed, please try again';
  @override
  String get leader => 'Leader';
  @override
  String get location => 'Location';
  @override
  String get updateTime => 'Updated';
  @override
  String get locate => 'Locate';
  @override
  String get navigateToMember => 'Navigate';
  @override
  String planningRouteToMember(String name) => 'Planning route to $name...';
  @override
  String get cannotGetLocation =>
      'Cannot get current location. Please enable location permission';
  @override
  String secondsAgo(int seconds) => '${seconds}s ago';
  @override
  String minutesAgo(int minutes) => '${minutes}m ago';
  @override
  String hoursAgo(int hours) => '${hours}h ago';

  // Meeting points
  @override
  String get meetingPoint => 'Meeting Point';
  @override
  String get noMeetingPoints => 'No meeting points';
  @override
  String get noMeetingPointsHint =>
      'Select a location on the map and click "Add Meeting Point"';
  @override
  String get addMeetingPointHint =>
      'Select a location on the map and click "Add Meeting Point"';
  @override
  String createdBy(String name) => 'Created by $name';
  @override
  String get setAsActive => 'Set as active meeting point';
  @override
  String get unsetActive => 'Unset as active meeting point';
  @override
  String get setAsCurrentMeetingPoint => 'Set as current meeting point';
  @override
  String get unsetAsCurrentMeetingPoint => 'Unset as current meeting point';
  @override
  String get editName => 'Edit name';
  @override
  String get navigateTo => 'Navigate here';
  @override
  String get editMeetingPointName => 'Edit Meeting Point Name';
  @override
  String get name => 'Name';
  @override
  String get deleteMeetingPoint => 'Delete Meeting Point';
  @override
  String deleteMeetingPointConfirm(String name) =>
      'Are you sure you want to delete meeting point "$name"?';
  @override
  String get addMeetingPoint => 'Add Meeting Point';
  @override
  String get meetingPointName => 'Meeting point name';
  @override
  String meetingPointAdded(String name) => 'Meeting point "$name" added';
  @override
  String get addMeetingPointFailed => 'Failed to add meeting point';
  @override
  String meetingPointLabel(String location) => 'Meeting point $location';

  // Piste info
  @override
  String get difficulty => 'Difficulty';
  @override
  String get distance => 'Distance';
  @override
  String get ascent => 'Ascent';
  @override
  String get descent => 'Descent';
  @override
  String get avgSlope => 'Avg Slope';
  @override
  String get ref => 'Ref';
  @override
  String get type => 'Type';
  @override
  String get length => 'Length';
  @override
  String get noElevationData => 'No elevation data available';
  @override
  String get liftType => 'Lift Type';

  // Language
  @override
  String get language => 'Language';
  @override
  String get chinese => '中文';
  @override
  String get english => 'English';

  // Xiaohongshu
  @override
  String get followOnXiaohongshu => 'Follow me on 小红书 @了不起的okboy';
}
