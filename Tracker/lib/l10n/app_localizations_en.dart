import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SnowNavi Tracker';

  @override
  String get tabRecord => 'Record';

  @override
  String get tabMap => 'Map';

  @override
  String get tabHistory => 'History';

  @override
  String get tabMe => 'Me';

  @override
  String get loading => 'Loading...';

  @override
  String get recordingInterrupted => 'Recording Interrupted';

  @override
  String get recordingInterruptedMessage => 'A recording session was interrupted. Would you like to continue?';

  @override
  String started(String time) {
    return 'Started: $time';
  }

  @override
  String duration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get discard => 'Discard';

  @override
  String get continueRecording => 'Continue Recording';

  @override
  String get sharedRouteFound => 'Shared Route Found';

  @override
  String get sharedRouteMessage => 'A shared route was detected in clipboard. Import it?';

  @override
  String resort(String name) {
    return 'Resort: $name';
  }

  @override
  String route(String origin, String destination) {
    return 'Route: $origin → $destination';
  }

  @override
  String stopovers(int count) {
    return 'Stopovers: $count';
  }

  @override
  String get ignore => 'Ignore';

  @override
  String get importRoute => 'Import Route';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get speed => 'Speed';

  @override
  String get altitude => 'Altitude';

  @override
  String get distance => 'Distance';

  @override
  String get maxSpeed => 'Max Speed';

  @override
  String get avgSpeed => 'Avg Speed';

  @override
  String get elevationGain => 'Elevation Gain';

  @override
  String get elevationLoss => 'Elevation Loss';

  @override
  String get noLocationData => 'No location data';

  @override
  String get waitingForGPS => 'Waiting for GPS...';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get alwaysLocationPermission => 'Background location access is required for track recording while the app is in background.';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get later => 'Later';

  @override
  String get noTracksToExport => 'No tracks to export';

  @override
  String get exportTracks => 'Export Tracks';

  @override
  String get importTracks => 'Import Tracks';

  @override
  String get deleteTrack => 'Delete Track';

  @override
  String get deleteTrackConfirm => 'Are you sure you want to delete this track?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get refresh => 'Refresh';

  @override
  String get share => 'Share';

  @override
  String get edit => 'Edit';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get notDownloaded => 'Not Downloaded';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get loginSuccess => 'Login successful';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get enterEmail => 'Enter email address';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get emptyEmail => 'Please enter email address';

  @override
  String get memberLogin => 'Member Login';

  @override
  String get memberLoginHint => 'Login to use features like team skiing';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get enterRegisteredEmail => 'Enter your registered email';

  @override
  String get goToLogin => 'Go to Login';

  @override
  String get member => 'Member';

  @override
  String get admin => 'Admin';

  @override
  String get superAdmin => 'Super Admin';

  @override
  String get coach => 'Coach';

  @override
  String get nameNotSet => 'Name not set';

  @override
  String get memberQRCode => 'Member QR Code';

  @override
  String get scanToVerify => 'Scan to verify member status';

  @override
  String get team => 'Team';

  @override
  String get teamSkiing => 'Team Skiing';

  @override
  String get createTeam => 'Create Team';

  @override
  String get joinTeam => 'Join Team';

  @override
  String get leaveTeam => 'Leave Team';

  @override
  String get leaveTeamConfirm => 'Are you sure you want to leave the team?';

  @override
  String get teamCode => 'Team Code';

  @override
  String get teamCodeHint => 'Enter team code';

  @override
  String get teamName => 'Team Name';

  @override
  String get teamNameHint => 'e.g. SnowNavi';

  @override
  String get teamMembers => 'Team Members';

  @override
  String get teamSize => 'Team Size';

  @override
  String teamSizeFormat(int count) {
    return '$count people';
  }

  @override
  String teamCodeFormat(String code) {
    return 'Team Code: $code';
  }

  @override
  String get shareLocation => 'Share Location';

  @override
  String get shareMyLocation => 'Share my location';

  @override
  String get nickname => 'Nickname';

  @override
  String get newNickname => 'New Nickname';

  @override
  String get enterNewNickname => 'Enter new nickname';

  @override
  String get editNickname => 'Edit Nickname';

  @override
  String get nicknameUpdated => 'Nickname updated';

  @override
  String get inviteLink => 'Invite Link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get createNewTeam => 'Create New Team';

  @override
  String get joinExistingTeam => 'Join Existing Team';

  @override
  String get loginRequired => 'Login Required';

  @override
  String get teamSkiingRequiresLogin => 'Team skiing requires member login';

  @override
  String get pleaseEnterTeamName => 'Please enter team name';

  @override
  String get pleaseEnterTeamCode => 'Please enter team code';

  @override
  String get createFailed => 'Create failed';

  @override
  String get joinFailed => 'Join failed';

  @override
  String get refreshed => 'Refreshed';

  @override
  String get refreshMemberLocations => 'Refresh member locations';

  @override
  String membersLimit(int count) {
    return 'Limit: $count people';
  }

  @override
  String get setMembersLimit => 'Set Member Limit';

  @override
  String get featureNotAvailable => 'This feature is not available yet';

  @override
  String get sharingLocation => 'Sharing location';

  @override
  String get locationSharingActive => 'Location sharing active';

  @override
  String get locationExpired => 'Location expired';

  @override
  String get notSharingLocation => 'Not sharing location';

  @override
  String get me => 'me';

  @override
  String get leader => 'Leader';

  @override
  String get removeMember => 'Remove Member';

  @override
  String removeMemberConfirm(String name) {
    return 'Are you sure you want to remove $name from the team?';
  }

  @override
  String get meetingPoint => 'Meeting Point';

  @override
  String get meetingPoints => 'Meeting Points';

  @override
  String get setMeetingPoint => 'Set Meeting Point';

  @override
  String get clearMeetingPoint => 'Clear Meeting Point';

  @override
  String get navigateToMeetingPoint => 'Navigate to Meeting Point';

  @override
  String get noMeetingPoints => 'No meeting points';

  @override
  String get longPressToAddMeetingPoint => 'Long press on map to add meeting point';

  @override
  String get editMeetingPointName => 'Edit Meeting Point Name';

  @override
  String get deleteMeetingPoint => 'Delete Meeting Point';

  @override
  String deleteMeetingPointConfirm(String name) {
    return 'Are you sure you want to delete meeting point \"$name\"?';
  }

  @override
  String get setAsCurrentMeetingPoint => 'Set as current meeting point';

  @override
  String get cancelCurrentMeetingPoint => 'Cancel current meeting point';

  @override
  String get navigateHere => 'Navigate here';

  @override
  String createdBy(String name) {
    return 'Created by: $name';
  }

  @override
  String get name => 'Name';

  @override
  String get routePlanning => 'Route Planning';

  @override
  String get setOrigin => 'Set as Origin';

  @override
  String get setDestination => 'Set as Destination';

  @override
  String get addStopover => 'Add Stopover';

  @override
  String get addAsMeetingPoint => 'Add as Meeting Point';

  @override
  String get calculateRoute => 'Calculate Route';

  @override
  String get clearRoute => 'Clear Route';

  @override
  String get shareRoute => 'Share Route';

  @override
  String get origin => 'Origin';

  @override
  String get destination => 'Destination';

  @override
  String get stopover => 'Stopover';

  @override
  String stopoverNumber(int number) {
    return 'Stopover $number';
  }

  @override
  String clickToSelect(String label) {
    return 'Click to select $label';
  }

  @override
  String get searchOrigin => 'Search origin';

  @override
  String get searchDestination => 'Search destination';

  @override
  String searchStopover(int number) {
    return 'Search stopover $number';
  }

  @override
  String get searchNewStopover => 'Search new stopover';

  @override
  String get searchLocation => 'Search location';

  @override
  String get useCurrentLocation => 'Use current location';

  @override
  String get longPressMapToSelect => 'Long press on map to select any location';

  @override
  String get routeDetails => 'Route Details';

  @override
  String get unnamedPiste => 'Unnamed piste';

  @override
  String get selectedLocation => 'Selected Location';

  @override
  String get selectResort => 'Select Resort';

  @override
  String get layerSettings => 'Layer Settings';

  @override
  String get pistesAndLifts => 'Pistes and Lifts';

  @override
  String get showResortPistesAndLifts => 'Show pistes and lifts for current resort';

  @override
  String get openSnowMap => 'OpenSnowMap';

  @override
  String get showOpenSnowMapLayer => 'Show OpenSnowMap ski layer';

  @override
  String get teammateLocations => 'Teammate Locations';

  @override
  String get showTeammateLocations => 'Show real-time locations of team members';

  @override
  String get showMeetingPoints => 'Show meeting points';

  @override
  String get offlineMap => 'Offline Map';

  @override
  String get offlineDataManagement => 'Offline Data Management';

  @override
  String get offlineMaps => 'Offline Maps';

  @override
  String get navigationData => 'Navigation Data';

  @override
  String get downloadMap => 'Download Map';

  @override
  String get deleteMap => 'Delete Map';

  @override
  String get deleteOfflineMap => 'Delete Offline Map';

  @override
  String deleteOfflineMapConfirm(String name) {
    return 'Are you sure you want to delete the offline map for $name?';
  }

  @override
  String offlineMapDownloaded(String name) {
    return '$name offline map downloaded';
  }

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get downloadMapsForOffline => 'Download resort maps for offline use';

  @override
  String get importNavFile => 'Import Navigation File';

  @override
  String get noNavigationData => 'No navigation data';

  @override
  String get clickToImportSqlite => 'Click above to import .sqlite file';

  @override
  String get importNavDataForOffline => 'Import resort navigation data for offline route planning';

  @override
  String get selectResortForNavFile => 'Select Resort for Navigation File';

  @override
  String get navDataImportSuccess => 'Navigation data imported successfully';

  @override
  String get importFailed => 'Import failed, file may be invalid';

  @override
  String get cannotAccessFile => 'Cannot access file';

  @override
  String get pleaseSelectSqliteFile => 'Please select a .sqlite navigation file';

  @override
  String get deleteNavData => 'Delete Navigation Data';

  @override
  String deleteNavDataConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get units => 'Units';

  @override
  String get metric => 'Metric';

  @override
  String get imperial => 'Imperial';

  @override
  String get unknown => 'Unknown';

  @override
  String get unknownResort => 'Unknown Resort';

  @override
  String hourMinute(int hours, int minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String minuteOnly(int minutes) {
    return '$minutes min';
  }

  @override
  String secondsFormat(int seconds) {
    return '$seconds sec';
  }

  @override
  String minSecFormat(int minutes, int seconds) {
    return '$minutes min ${seconds}s';
  }

  @override
  String get videoExport => 'Video Export';

  @override
  String get microphonePermissionNote => 'Microphone permission is required to record audio from videos.';

  @override
  String get startExport => 'Start Export';

  @override
  String get stopExport => 'Stop Export';

  @override
  String get exportComplete => 'Export Complete';

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get saveToGallery => 'Save to Gallery';

  @override
  String get videoOnTrack => 'Video on Track';

  @override
  String get fullPlayback => 'Full Playback';

  @override
  String get playFullVideoOnTrack => 'Play full video on track';

  @override
  String get fixedDurationSkip => 'Fixed Duration Skip';

  @override
  String get playFixedSecondsAndSkip => 'Play for fixed seconds then skip';

  @override
  String get skipMedia => 'Skip Media';

  @override
  String get skipAllPhotosAndVideos => 'Skip all photos and videos';

  @override
  String get secondsUnit => 'sec';

  @override
  String get rec => 'REC';

  @override
  String get unableToStartRecording => 'Unable to start recording';

  @override
  String get gpsNoSignal => 'No GPS';

  @override
  String get gpsWeak => 'Weak';

  @override
  String get gpsFair => 'Fair';

  @override
  String get gpsGood => 'Good';

  @override
  String get gpsExcellent => 'Excellent';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusAutoPaused => 'Auto-Paused';

  @override
  String get statusRecording => 'Recording';

  @override
  String get stopRecordingTitle => 'Stop Recording?';

  @override
  String get stopRecordingMessage => 'Are you sure you want to stop this session?';

  @override
  String get history => 'History';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get exportAllTracks => 'Export All Tracks';

  @override
  String get backupToZip => 'Backup to ZIP file and share';

  @override
  String get importFromBackup => 'Restore from backup file';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String get startRecordingHint => 'Start recording to see your sessions here';

  @override
  String get totalDuration => 'Total Duration';

  @override
  String get skiingDuration => 'Skiing Duration';

  @override
  String get totalDistance => 'Total Distance';

  @override
  String get skiingDistance => 'Skiing Distance';

  @override
  String get deleteSession => 'Delete Session?';

  @override
  String get deleteSessionWarning => 'This action cannot be undone.';

  @override
  String get sessionDetails => 'Session Details';

  @override
  String get replay3D => '3D Replay';

  @override
  String get showHidePhotos => 'Show/Hide Photos';

  @override
  String get exportGPX => 'Export GPX';

  @override
  String get noTrackData => 'No track data';

  @override
  String get tapToShowControls => 'Tap to show controls';

  @override
  String get skip => 'Skip';

  @override
  String get failedToExportGPX => 'Failed to export GPX';

  @override
  String get unableToGetCurrentLocation => 'Unable to get current location';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get pleaseJoinOrCreateTeam => 'Please join or create a team first';

  @override
  String get addMeetingPoint => 'Add Meeting Point';

  @override
  String get meetingPointName => 'Meeting point name';

  @override
  String get enterMeetingPointName => 'Enter meeting point name';

  @override
  String meetingPointAdded(String name) {
    return 'Meeting point \"$name\" added';
  }

  @override
  String addMeetingPointFailed(String error) {
    return 'Failed to add meeting point: $error';
  }

  @override
  String get downloadOfflineMaps => 'Download resort maps for offline use';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours hr ago';
  }

  @override
  String locationUpdatedAt(String time) {
    return 'Location updated $time';
  }

  @override
  String get planRouteToMember => 'Plan route to them';

  @override
  String get activeMeetingPoint => 'Active Meeting Point';

  @override
  String get planRoute => 'Plan Route';

  @override
  String get setAsActive => 'Set as Active';

  @override
  String get chairLift => 'Chair Lift';

  @override
  String get gondolaLift => 'Gondola';

  @override
  String get cableCar => 'Cable Car';

  @override
  String get dragLift => 'Drag Lift';

  @override
  String get magicCarpet => 'Magic Carpet';

  @override
  String get lift => 'Lift';

  @override
  String get noviceDifficulty => 'Novice';

  @override
  String get easyDifficulty => 'Easy';

  @override
  String get intermediateDifficulty => 'Intermediate';

  @override
  String get advancedDifficulty => 'Advanced';

  @override
  String get expertDifficulty => 'Expert';

  @override
  String get freerideDifficulty => 'Freeride';

  @override
  String get shareGpxText => 'Ski Session GPX';

  @override
  String get confirmFilter => 'Confirm Filter';

  @override
  String filteredMediaCount(int count) {
    return 'Filtered $count media';
  }

  @override
  String get speedFast => 'Fast (15s)';

  @override
  String get speedNormal => 'Normal (30s)';

  @override
  String get speedSlow => 'Slow (45s)';

  @override
  String get reset => 'Reset';

  @override
  String get presets => 'Presets';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get done => 'Done';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get emailOpenedAddAttachment => 'Email opened, please add attachment manually';

  @override
  String get shareToOtherApps => 'Share to other apps';

  @override
  String get wechatQQEtc => 'WeChat, QQ, etc.';

  @override
  String get copyShareText => 'Copy share text';

  @override
  String get copyShareTextHint => 'Recipient can open App to auto-load after copying';

  @override
  String get feedbackRouteProblem => 'Report route problem';

  @override
  String sendToEmail(String email) {
    return 'Send to $email';
  }

  @override
  String get routeShareTextCopied => 'Route share text copied';

  @override
  String get replayDuration => 'Replay Duration';

  @override
  String get cameraZoom => 'Camera Zoom';

  @override
  String get cameraTilt => 'Camera Tilt';

  @override
  String get lookAheadPoints => 'Look-ahead Points';

  @override
  String get directionSmoothing => 'Direction Smoothing';

  @override
  String get photoDuration => 'Photo Duration';

  @override
  String get shareAttachment => 'Share Attachment';

  @override
  String get replaySettings => 'Replay Settings';

  @override
  String get mediaPlayback => 'Media Playback';

  @override
  String get showMediaDuringReplay => 'Show photos/videos during replay';

  @override
  String get showMediaDuringReplayHint => 'Auto display when track passes media location';

  @override
  String get unitSeconds => 'sec';

  @override
  String get unitPoints => 'pts';

  @override
  String get fast => 'Fast';

  @override
  String get normal => 'Normal';

  @override
  String get slow => 'Slow';
}
