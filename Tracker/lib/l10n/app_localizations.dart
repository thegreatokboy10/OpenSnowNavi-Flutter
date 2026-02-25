import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SnowNavi Tracker'**
  String get appTitle;

  /// No description provided for @tabRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get tabRecord;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabMe;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @recordingInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Recording Interrupted'**
  String get recordingInterrupted;

  /// No description provided for @recordingInterruptedMessage.
  ///
  /// In en, this message translates to:
  /// **'A recording session was interrupted. Would you like to continue?'**
  String get recordingInterruptedMessage;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started: {time}'**
  String started(String time);

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String duration(String duration);

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @continueRecording.
  ///
  /// In en, this message translates to:
  /// **'Continue Recording'**
  String get continueRecording;

  /// No description provided for @sharedRouteFound.
  ///
  /// In en, this message translates to:
  /// **'Shared Route Found'**
  String get sharedRouteFound;

  /// No description provided for @sharedRouteMessage.
  ///
  /// In en, this message translates to:
  /// **'A shared route was detected in clipboard. Import it?'**
  String get sharedRouteMessage;

  /// No description provided for @resort.
  ///
  /// In en, this message translates to:
  /// **'Resort: {name}'**
  String resort(String name);

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route: {origin} → {destination}'**
  String route(String origin, String destination);

  /// No description provided for @stopovers.
  ///
  /// In en, this message translates to:
  /// **'Stopovers: {count}'**
  String stopovers(int count);

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @importRoute.
  ///
  /// In en, this message translates to:
  /// **'Import Route'**
  String get importRoute;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitude;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @maxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max Speed'**
  String get maxSpeed;

  /// No description provided for @avgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get avgSpeed;

  /// No description provided for @elevationGain.
  ///
  /// In en, this message translates to:
  /// **'Elevation Gain'**
  String get elevationGain;

  /// No description provided for @elevationLoss.
  ///
  /// In en, this message translates to:
  /// **'Elevation Loss'**
  String get elevationLoss;

  /// No description provided for @noLocationData.
  ///
  /// In en, this message translates to:
  /// **'No location data'**
  String get noLocationData;

  /// No description provided for @waitingForGPS.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS...'**
  String get waitingForGPS;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// No description provided for @alwaysLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Background location access is required for track recording while the app is in background.'**
  String get alwaysLocationPermission;

  /// No description provided for @goToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get goToSettings;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @noTracksToExport.
  ///
  /// In en, this message translates to:
  /// **'No tracks to export'**
  String get noTracksToExport;

  /// No description provided for @exportTracks.
  ///
  /// In en, this message translates to:
  /// **'Export Tracks'**
  String get exportTracks;

  /// No description provided for @importTracks.
  ///
  /// In en, this message translates to:
  /// **'Import Tracks'**
  String get importTracks;

  /// No description provided for @deleteTrack.
  ///
  /// In en, this message translates to:
  /// **'Delete Track'**
  String get deleteTrack;

  /// No description provided for @deleteTrackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this track?'**
  String get deleteTrackConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @notDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not Downloaded'**
  String get notDownloaded;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccess;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @emptyEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter email address'**
  String get emptyEmail;

  /// No description provided for @memberLogin.
  ///
  /// In en, this message translates to:
  /// **'Member Login'**
  String get memberLogin;

  /// No description provided for @memberLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Login to use features like team skiing'**
  String get memberLoginHint;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @enterRegisteredEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email'**
  String get enterRegisteredEmail;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get goToLogin;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @superAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get superAdmin;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @nameNotSet.
  ///
  /// In en, this message translates to:
  /// **'Name not set'**
  String get nameNotSet;

  /// No description provided for @memberQRCode.
  ///
  /// In en, this message translates to:
  /// **'Member QR Code'**
  String get memberQRCode;

  /// No description provided for @scanToVerify.
  ///
  /// In en, this message translates to:
  /// **'Scan to verify member status'**
  String get scanToVerify;

  /// No description provided for @team.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get team;

  /// No description provided for @teamSkiing.
  ///
  /// In en, this message translates to:
  /// **'Team Skiing'**
  String get teamSkiing;

  /// No description provided for @createTeam.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get createTeam;

  /// No description provided for @joinTeam.
  ///
  /// In en, this message translates to:
  /// **'Join Team'**
  String get joinTeam;

  /// No description provided for @leaveTeam.
  ///
  /// In en, this message translates to:
  /// **'Leave Team'**
  String get leaveTeam;

  /// No description provided for @leaveTeamConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the team?'**
  String get leaveTeamConfirm;

  /// No description provided for @teamCode.
  ///
  /// In en, this message translates to:
  /// **'Team Code'**
  String get teamCode;

  /// No description provided for @teamCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter team code'**
  String get teamCodeHint;

  /// No description provided for @teamName.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get teamName;

  /// No description provided for @teamNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. SnowNavi'**
  String get teamNameHint;

  /// No description provided for @teamMembers.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get teamMembers;

  /// No description provided for @teamSize.
  ///
  /// In en, this message translates to:
  /// **'Team Size'**
  String get teamSize;

  /// No description provided for @teamSizeFormat.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String teamSizeFormat(int count);

  /// No description provided for @teamCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Team Code: {code}'**
  String teamCodeFormat(String code);

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share Location'**
  String get shareLocation;

  /// No description provided for @shareMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Share my location'**
  String get shareMyLocation;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @newNickname.
  ///
  /// In en, this message translates to:
  /// **'New Nickname'**
  String get newNickname;

  /// No description provided for @enterNewNickname.
  ///
  /// In en, this message translates to:
  /// **'Enter new nickname'**
  String get enterNewNickname;

  /// No description provided for @editNickname.
  ///
  /// In en, this message translates to:
  /// **'Edit Nickname'**
  String get editNickname;

  /// No description provided for @nicknameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Nickname updated'**
  String get nicknameUpdated;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite Link'**
  String get inviteLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @createNewTeam.
  ///
  /// In en, this message translates to:
  /// **'Create New Team'**
  String get createNewTeam;

  /// No description provided for @joinExistingTeam.
  ///
  /// In en, this message translates to:
  /// **'Join Existing Team'**
  String get joinExistingTeam;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @teamSkiingRequiresLogin.
  ///
  /// In en, this message translates to:
  /// **'Team skiing requires member login'**
  String get teamSkiingRequiresLogin;

  /// No description provided for @pleaseEnterTeamName.
  ///
  /// In en, this message translates to:
  /// **'Please enter team name'**
  String get pleaseEnterTeamName;

  /// No description provided for @pleaseEnterTeamCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter team code'**
  String get pleaseEnterTeamCode;

  /// No description provided for @createFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed'**
  String get createFailed;

  /// No description provided for @joinFailed.
  ///
  /// In en, this message translates to:
  /// **'Join failed'**
  String get joinFailed;

  /// No description provided for @refreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get refreshed;

  /// No description provided for @refreshMemberLocations.
  ///
  /// In en, this message translates to:
  /// **'Refresh member locations'**
  String get refreshMemberLocations;

  /// No description provided for @membersLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit: {count} people'**
  String membersLimit(int count);

  /// No description provided for @setMembersLimit.
  ///
  /// In en, this message translates to:
  /// **'Set Member Limit'**
  String get setMembersLimit;

  /// No description provided for @featureNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is not available yet'**
  String get featureNotAvailable;

  /// No description provided for @sharingLocation.
  ///
  /// In en, this message translates to:
  /// **'Sharing location'**
  String get sharingLocation;

  /// No description provided for @locationSharingActive.
  ///
  /// In en, this message translates to:
  /// **'Location sharing active'**
  String get locationSharingActive;

  /// No description provided for @locationExpired.
  ///
  /// In en, this message translates to:
  /// **'Location expired'**
  String get locationExpired;

  /// No description provided for @notSharingLocation.
  ///
  /// In en, this message translates to:
  /// **'Not sharing location'**
  String get notSharingLocation;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'me'**
  String get me;

  /// No description provided for @leader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get leader;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get removeMember;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name} from the team?'**
  String removeMemberConfirm(String name);

  /// No description provided for @meetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Meeting Point'**
  String get meetingPoint;

  /// No description provided for @meetingPoints.
  ///
  /// In en, this message translates to:
  /// **'Meeting Points'**
  String get meetingPoints;

  /// No description provided for @setMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Set Meeting Point'**
  String get setMeetingPoint;

  /// No description provided for @clearMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Clear Meeting Point'**
  String get clearMeetingPoint;

  /// No description provided for @navigateToMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Navigate to Meeting Point'**
  String get navigateToMeetingPoint;

  /// No description provided for @noMeetingPoints.
  ///
  /// In en, this message translates to:
  /// **'No meeting points'**
  String get noMeetingPoints;

  /// No description provided for @longPressToAddMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Long press on map to add meeting point'**
  String get longPressToAddMeetingPoint;

  /// No description provided for @editMeetingPointName.
  ///
  /// In en, this message translates to:
  /// **'Edit Meeting Point Name'**
  String get editMeetingPointName;

  /// No description provided for @deleteMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Delete Meeting Point'**
  String get deleteMeetingPoint;

  /// No description provided for @deleteMeetingPointConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete meeting point \"{name}\"?'**
  String deleteMeetingPointConfirm(String name);

  /// No description provided for @setAsCurrentMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Set as current meeting point'**
  String get setAsCurrentMeetingPoint;

  /// No description provided for @cancelCurrentMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Cancel current meeting point'**
  String get cancelCurrentMeetingPoint;

  /// No description provided for @navigateHere.
  ///
  /// In en, this message translates to:
  /// **'Navigate here'**
  String get navigateHere;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created by: {name}'**
  String createdBy(String name);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @routePlanning.
  ///
  /// In en, this message translates to:
  /// **'Route Planning'**
  String get routePlanning;

  /// No description provided for @setOrigin.
  ///
  /// In en, this message translates to:
  /// **'Set as Origin'**
  String get setOrigin;

  /// No description provided for @setDestination.
  ///
  /// In en, this message translates to:
  /// **'Set as Destination'**
  String get setDestination;

  /// No description provided for @addStopover.
  ///
  /// In en, this message translates to:
  /// **'Add Stopover'**
  String get addStopover;

  /// No description provided for @addAsMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Add as Meeting Point'**
  String get addAsMeetingPoint;

  /// No description provided for @calculateRoute.
  ///
  /// In en, this message translates to:
  /// **'Calculate Route'**
  String get calculateRoute;

  /// No description provided for @clearRoute.
  ///
  /// In en, this message translates to:
  /// **'Clear Route'**
  String get clearRoute;

  /// No description provided for @shareRoute.
  ///
  /// In en, this message translates to:
  /// **'Share Route'**
  String get shareRoute;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @stopover.
  ///
  /// In en, this message translates to:
  /// **'Stopover'**
  String get stopover;

  /// No description provided for @stopoverNumber.
  ///
  /// In en, this message translates to:
  /// **'Stopover {number}'**
  String stopoverNumber(int number);

  /// No description provided for @clickToSelect.
  ///
  /// In en, this message translates to:
  /// **'Click to select {label}'**
  String clickToSelect(String label);

  /// No description provided for @searchOrigin.
  ///
  /// In en, this message translates to:
  /// **'Search origin'**
  String get searchOrigin;

  /// No description provided for @searchDestination.
  ///
  /// In en, this message translates to:
  /// **'Search destination'**
  String get searchDestination;

  /// No description provided for @searchStopover.
  ///
  /// In en, this message translates to:
  /// **'Search stopover {number}'**
  String searchStopover(int number);

  /// No description provided for @searchNewStopover.
  ///
  /// In en, this message translates to:
  /// **'Search new stopover'**
  String get searchNewStopover;

  /// No description provided for @searchLocation.
  ///
  /// In en, this message translates to:
  /// **'Search location'**
  String get searchLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @longPressMapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Long press on map to select any location'**
  String get longPressMapToSelect;

  /// No description provided for @routeDetails.
  ///
  /// In en, this message translates to:
  /// **'Route Details'**
  String get routeDetails;

  /// No description provided for @unnamedPiste.
  ///
  /// In en, this message translates to:
  /// **'Unnamed piste'**
  String get unnamedPiste;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocation;

  /// No description provided for @selectResort.
  ///
  /// In en, this message translates to:
  /// **'Select Resort'**
  String get selectResort;

  /// No description provided for @layerSettings.
  ///
  /// In en, this message translates to:
  /// **'Layer Settings'**
  String get layerSettings;

  /// No description provided for @pistesAndLifts.
  ///
  /// In en, this message translates to:
  /// **'Pistes and Lifts'**
  String get pistesAndLifts;

  /// No description provided for @showResortPistesAndLifts.
  ///
  /// In en, this message translates to:
  /// **'Show pistes and lifts for current resort'**
  String get showResortPistesAndLifts;

  /// No description provided for @openSnowMap.
  ///
  /// In en, this message translates to:
  /// **'OpenSnowMap'**
  String get openSnowMap;

  /// No description provided for @showOpenSnowMapLayer.
  ///
  /// In en, this message translates to:
  /// **'Show OpenSnowMap ski layer'**
  String get showOpenSnowMapLayer;

  /// No description provided for @teammateLocations.
  ///
  /// In en, this message translates to:
  /// **'Teammate Locations'**
  String get teammateLocations;

  /// No description provided for @showTeammateLocations.
  ///
  /// In en, this message translates to:
  /// **'Show real-time locations of team members'**
  String get showTeammateLocations;

  /// No description provided for @showMeetingPoints.
  ///
  /// In en, this message translates to:
  /// **'Show meeting points'**
  String get showMeetingPoints;

  /// No description provided for @offlineMap.
  ///
  /// In en, this message translates to:
  /// **'Offline Map'**
  String get offlineMap;

  /// No description provided for @offlineDataManagement.
  ///
  /// In en, this message translates to:
  /// **'Offline Data Management'**
  String get offlineDataManagement;

  /// No description provided for @offlineMaps.
  ///
  /// In en, this message translates to:
  /// **'Offline Maps'**
  String get offlineMaps;

  /// No description provided for @navigationData.
  ///
  /// In en, this message translates to:
  /// **'Navigation Data'**
  String get navigationData;

  /// No description provided for @downloadMap.
  ///
  /// In en, this message translates to:
  /// **'Download Map'**
  String get downloadMap;

  /// No description provided for @deleteMap.
  ///
  /// In en, this message translates to:
  /// **'Delete Map'**
  String get deleteMap;

  /// No description provided for @deleteOfflineMap.
  ///
  /// In en, this message translates to:
  /// **'Delete Offline Map'**
  String get deleteOfflineMap;

  /// No description provided for @deleteOfflineMapConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the offline map for {name}?'**
  String deleteOfflineMapConfirm(String name);

  /// No description provided for @offlineMapDownloaded.
  ///
  /// In en, this message translates to:
  /// **'{name} offline map downloaded'**
  String offlineMapDownloaded(String name);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @downloadMapsForOffline.
  ///
  /// In en, this message translates to:
  /// **'Download resort maps for offline use'**
  String get downloadMapsForOffline;

  /// No description provided for @importNavFile.
  ///
  /// In en, this message translates to:
  /// **'Import Navigation File'**
  String get importNavFile;

  /// No description provided for @noNavigationData.
  ///
  /// In en, this message translates to:
  /// **'No navigation data'**
  String get noNavigationData;

  /// No description provided for @clickToImportSqlite.
  ///
  /// In en, this message translates to:
  /// **'Click above to import .sqlite file'**
  String get clickToImportSqlite;

  /// No description provided for @importNavDataForOffline.
  ///
  /// In en, this message translates to:
  /// **'Import resort navigation data for offline route planning'**
  String get importNavDataForOffline;

  /// No description provided for @selectResortForNavFile.
  ///
  /// In en, this message translates to:
  /// **'Select Resort for Navigation File'**
  String get selectResortForNavFile;

  /// No description provided for @navDataImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Navigation data imported successfully'**
  String get navDataImportSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed, file may be invalid'**
  String get importFailed;

  /// No description provided for @cannotAccessFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot access file'**
  String get cannotAccessFile;

  /// No description provided for @pleaseSelectSqliteFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a .sqlite navigation file'**
  String get pleaseSelectSqliteFile;

  /// No description provided for @deleteNavData.
  ///
  /// In en, this message translates to:
  /// **'Delete Navigation Data'**
  String get deleteNavData;

  /// No description provided for @deleteNavDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteNavDataConfirm(String name);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownResort.
  ///
  /// In en, this message translates to:
  /// **'Unknown Resort'**
  String get unknownResort;

  /// No description provided for @hourMinute.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String hourMinute(int hours, int minutes);

  /// No description provided for @minuteOnly.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minuteOnly(int minutes);

  /// No description provided for @secondsFormat.
  ///
  /// In en, this message translates to:
  /// **'{seconds} sec'**
  String secondsFormat(int seconds);

  /// No description provided for @minSecFormat.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds}s'**
  String minSecFormat(int minutes, int seconds);

  /// No description provided for @videoExport.
  ///
  /// In en, this message translates to:
  /// **'Video Export'**
  String get videoExport;

  /// No description provided for @microphonePermissionNote.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to record audio from videos.'**
  String get microphonePermissionNote;

  /// No description provided for @startExport.
  ///
  /// In en, this message translates to:
  /// **'Start Export'**
  String get startExport;

  /// No description provided for @stopExport.
  ///
  /// In en, this message translates to:
  /// **'Stop Export'**
  String get stopExport;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Export Complete'**
  String get exportComplete;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get exportCancelled;

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get savedToGallery;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get saveFailed;

  /// No description provided for @saveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get saveToGallery;

  /// No description provided for @videoOnTrack.
  ///
  /// In en, this message translates to:
  /// **'Video on Track'**
  String get videoOnTrack;

  /// No description provided for @fullPlayback.
  ///
  /// In en, this message translates to:
  /// **'Full Playback'**
  String get fullPlayback;

  /// No description provided for @playFullVideoOnTrack.
  ///
  /// In en, this message translates to:
  /// **'Play full video on track'**
  String get playFullVideoOnTrack;

  /// No description provided for @fixedDurationSkip.
  ///
  /// In en, this message translates to:
  /// **'Fixed Duration Skip'**
  String get fixedDurationSkip;

  /// No description provided for @playFixedSecondsAndSkip.
  ///
  /// In en, this message translates to:
  /// **'Play for fixed seconds then skip'**
  String get playFixedSecondsAndSkip;

  /// No description provided for @skipMedia.
  ///
  /// In en, this message translates to:
  /// **'Skip Media'**
  String get skipMedia;

  /// No description provided for @skipAllPhotosAndVideos.
  ///
  /// In en, this message translates to:
  /// **'Skip all photos and videos'**
  String get skipAllPhotosAndVideos;

  /// No description provided for @secondsUnit.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get secondsUnit;

  /// No description provided for @rec.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get rec;

  /// No description provided for @unableToStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Unable to start recording'**
  String get unableToStartRecording;

  /// No description provided for @gpsNoSignal.
  ///
  /// In en, this message translates to:
  /// **'No GPS'**
  String get gpsNoSignal;

  /// No description provided for @gpsWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get gpsWeak;

  /// No description provided for @gpsFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get gpsFair;

  /// No description provided for @gpsGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get gpsGood;

  /// No description provided for @gpsExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get gpsExcellent;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusAutoPaused.
  ///
  /// In en, this message translates to:
  /// **'Auto-Paused'**
  String get statusAutoPaused;

  /// No description provided for @statusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get statusRecording;

  /// No description provided for @stopRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording?'**
  String get stopRecordingTitle;

  /// No description provided for @stopRecordingMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop this session?'**
  String get stopRecordingMessage;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @exportAllTracks.
  ///
  /// In en, this message translates to:
  /// **'Export All Tracks'**
  String get exportAllTracks;

  /// No description provided for @backupToZip.
  ///
  /// In en, this message translates to:
  /// **'Backup to ZIP file and share'**
  String get backupToZip;

  /// No description provided for @importFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup file'**
  String get importFromBackup;

  /// No description provided for @noSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// No description provided for @startRecordingHint.
  ///
  /// In en, this message translates to:
  /// **'Start recording to see your sessions here'**
  String get startRecordingHint;

  /// No description provided for @totalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total Duration'**
  String get totalDuration;

  /// No description provided for @skiingDuration.
  ///
  /// In en, this message translates to:
  /// **'Skiing Duration'**
  String get skiingDuration;

  /// No description provided for @totalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get totalDistance;

  /// No description provided for @skiingDistance.
  ///
  /// In en, this message translates to:
  /// **'Skiing Distance'**
  String get skiingDistance;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete Session?'**
  String get deleteSession;

  /// No description provided for @deleteSessionWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteSessionWarning;

  /// No description provided for @sessionDetails.
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get sessionDetails;

  /// No description provided for @replay3D.
  ///
  /// In en, this message translates to:
  /// **'3D Replay'**
  String get replay3D;

  /// No description provided for @showHidePhotos.
  ///
  /// In en, this message translates to:
  /// **'Show/Hide Photos'**
  String get showHidePhotos;

  /// No description provided for @exportGPX.
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get exportGPX;

  /// No description provided for @noTrackData.
  ///
  /// In en, this message translates to:
  /// **'No track data'**
  String get noTrackData;

  /// No description provided for @tapToShowControls.
  ///
  /// In en, this message translates to:
  /// **'Tap to show controls'**
  String get tapToShowControls;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @failedToExportGPX.
  ///
  /// In en, this message translates to:
  /// **'Failed to export GPX'**
  String get failedToExportGPX;

  /// No description provided for @unableToGetCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to get current location'**
  String get unableToGetCurrentLocation;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @pleaseJoinOrCreateTeam.
  ///
  /// In en, this message translates to:
  /// **'Please join or create a team first'**
  String get pleaseJoinOrCreateTeam;

  /// No description provided for @addMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Add Meeting Point'**
  String get addMeetingPoint;

  /// No description provided for @meetingPointName.
  ///
  /// In en, this message translates to:
  /// **'Meeting point name'**
  String get meetingPointName;

  /// No description provided for @enterMeetingPointName.
  ///
  /// In en, this message translates to:
  /// **'Enter meeting point name'**
  String get enterMeetingPointName;

  /// No description provided for @meetingPointAdded.
  ///
  /// In en, this message translates to:
  /// **'Meeting point \"{name}\" added'**
  String meetingPointAdded(String name);

  /// No description provided for @addMeetingPointFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add meeting point: {error}'**
  String addMeetingPointFailed(String error);

  /// No description provided for @downloadOfflineMaps.
  ///
  /// In en, this message translates to:
  /// **'Download resort maps for offline use'**
  String get downloadOfflineMaps;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String hoursAgo(int hours);

  /// No description provided for @locationUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Location updated {time}'**
  String locationUpdatedAt(String time);

  /// No description provided for @planRouteToMember.
  ///
  /// In en, this message translates to:
  /// **'Plan route to them'**
  String get planRouteToMember;

  /// No description provided for @activeMeetingPoint.
  ///
  /// In en, this message translates to:
  /// **'Active Meeting Point'**
  String get activeMeetingPoint;

  /// No description provided for @planRoute.
  ///
  /// In en, this message translates to:
  /// **'Plan Route'**
  String get planRoute;

  /// No description provided for @setAsActive.
  ///
  /// In en, this message translates to:
  /// **'Set as Active'**
  String get setAsActive;

  /// No description provided for @chairLift.
  ///
  /// In en, this message translates to:
  /// **'Chair Lift'**
  String get chairLift;

  /// No description provided for @gondolaLift.
  ///
  /// In en, this message translates to:
  /// **'Gondola'**
  String get gondolaLift;

  /// No description provided for @cableCar.
  ///
  /// In en, this message translates to:
  /// **'Cable Car'**
  String get cableCar;

  /// No description provided for @dragLift.
  ///
  /// In en, this message translates to:
  /// **'Drag Lift'**
  String get dragLift;

  /// No description provided for @magicCarpet.
  ///
  /// In en, this message translates to:
  /// **'Magic Carpet'**
  String get magicCarpet;

  /// No description provided for @lift.
  ///
  /// In en, this message translates to:
  /// **'Lift'**
  String get lift;

  /// No description provided for @noviceDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Novice'**
  String get noviceDifficulty;

  /// No description provided for @easyDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easyDifficulty;

  /// No description provided for @intermediateDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediateDifficulty;

  /// No description provided for @advancedDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedDifficulty;

  /// No description provided for @expertDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get expertDifficulty;

  /// No description provided for @freerideDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Freeride'**
  String get freerideDifficulty;

  /// No description provided for @shareGpxText.
  ///
  /// In en, this message translates to:
  /// **'Ski Session GPX'**
  String get shareGpxText;

  /// No description provided for @confirmFilter.
  ///
  /// In en, this message translates to:
  /// **'Confirm Filter'**
  String get confirmFilter;

  /// No description provided for @filteredMediaCount.
  ///
  /// In en, this message translates to:
  /// **'Filtered {count} media'**
  String filteredMediaCount(int count);

  /// No description provided for @speedFast.
  ///
  /// In en, this message translates to:
  /// **'Fast (15s)'**
  String get speedFast;

  /// No description provided for @speedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal (30s)'**
  String get speedNormal;

  /// No description provided for @speedSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow (45s)'**
  String get speedSlow;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @emailOpenedAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Email opened, please add attachment manually'**
  String get emailOpenedAddAttachment;

  /// No description provided for @shareToOtherApps.
  ///
  /// In en, this message translates to:
  /// **'Share to other apps'**
  String get shareToOtherApps;

  /// No description provided for @wechatQQEtc.
  ///
  /// In en, this message translates to:
  /// **'WeChat, QQ, etc.'**
  String get wechatQQEtc;

  /// No description provided for @copyShareText.
  ///
  /// In en, this message translates to:
  /// **'Copy share text'**
  String get copyShareText;

  /// No description provided for @copyShareTextHint.
  ///
  /// In en, this message translates to:
  /// **'Recipient can open App to auto-load after copying'**
  String get copyShareTextHint;

  /// No description provided for @feedbackRouteProblem.
  ///
  /// In en, this message translates to:
  /// **'Report route problem'**
  String get feedbackRouteProblem;

  /// No description provided for @sendToEmail.
  ///
  /// In en, this message translates to:
  /// **'Send to {email}'**
  String sendToEmail(String email);

  /// No description provided for @routeShareTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Route share text copied'**
  String get routeShareTextCopied;

  /// No description provided for @replayDuration.
  ///
  /// In en, this message translates to:
  /// **'Replay Duration'**
  String get replayDuration;

  /// No description provided for @cameraZoom.
  ///
  /// In en, this message translates to:
  /// **'Camera Zoom'**
  String get cameraZoom;

  /// No description provided for @cameraTilt.
  ///
  /// In en, this message translates to:
  /// **'Camera Tilt'**
  String get cameraTilt;

  /// No description provided for @lookAheadPoints.
  ///
  /// In en, this message translates to:
  /// **'Look-ahead Points'**
  String get lookAheadPoints;

  /// No description provided for @directionSmoothing.
  ///
  /// In en, this message translates to:
  /// **'Direction Smoothing'**
  String get directionSmoothing;

  /// No description provided for @photoDuration.
  ///
  /// In en, this message translates to:
  /// **'Photo Duration'**
  String get photoDuration;

  /// No description provided for @shareAttachment.
  ///
  /// In en, this message translates to:
  /// **'Share Attachment'**
  String get shareAttachment;

  /// No description provided for @replaySettings.
  ///
  /// In en, this message translates to:
  /// **'Replay Settings'**
  String get replaySettings;

  /// No description provided for @mediaPlayback.
  ///
  /// In en, this message translates to:
  /// **'Media Playback'**
  String get mediaPlayback;

  /// No description provided for @showMediaDuringReplay.
  ///
  /// In en, this message translates to:
  /// **'Show photos/videos during replay'**
  String get showMediaDuringReplay;

  /// No description provided for @showMediaDuringReplayHint.
  ///
  /// In en, this message translates to:
  /// **'Auto display when track passes media location'**
  String get showMediaDuringReplayHint;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get unitSeconds;

  /// No description provided for @unitPoints.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get unitPoints;

  /// No description provided for @fast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get fast;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @slow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get slow;

  /// No description provided for @elevationProfile.
  ///
  /// In en, this message translates to:
  /// **'Elevation Profile'**
  String get elevationProfile;

  /// No description provided for @loadingElevation.
  ///
  /// In en, this message translates to:
  /// **'Loading elevation data...'**
  String get loadingElevation;

  /// No description provided for @elevationLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load elevation data'**
  String get elevationLoadError;

  /// No description provided for @noElevationData.
  ///
  /// In en, this message translates to:
  /// **'No elevation data available'**
  String get noElevationData;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return SEn();
    case 'zh': return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
