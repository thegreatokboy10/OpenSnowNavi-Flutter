/// 应用字符串抽象基类
/// 所有语言的字符串实现都需要继承此类
abstract class AppStrings {
  // 通用
  String get appName;
  String get appTitle;
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get close;
  String get refresh;
  String get loading;
  String get error;
  String get unknown;
  String get confirm;
  String get add;
  String get followMeOnSocialMedia;

  // 地图相关
  String get loadingMap;
  String get filter;
  String get filterPistes;
  String get locateMe;
  String get share;
  String get layers;
  String get mapLayers;
  String get openSnowMap;
  String get openSnowMapDesc;
  String get searchPoi;
  String get noResults;
  String get openPhoto;
  String get select;

  // 难度级别
  String get difficultyNovice;
  String get difficultyEasy;
  String get difficultyIntermediate;
  String get difficultyAdvanced;
  String get difficultyExpert;
  String get difficultyFreeride;
  String getDifficultyName(String difficulty);

  // 2D/3D 切换
  String get mode2D;
  String get mode3D;
  String headingLabel(String heading);

  // 路线规划
  String get routePlanning;
  String get origin;
  String get destination;
  String get stopover;
  String stopoverN(int n);
  String get addStopover;
  String get setAsOrigin;
  String get setAsDestination;
  String get setAsStopover;
  String get addAsStopover;
  String get route;
  String get routeDetails;
  String get searchOrigin;
  String get searchDestination;
  String searchStopoverN(int n);
  String get searchNewStopover;
  String get clickToSelect;
  String clickToSelectLabel(String label);
  String originWithCoords(String coords);
  String destinationWithCoords(String coords);
  String stopoverWithCoords(int n, String coords);
  String get currentLocation;
  String get fromPhoto;
  String get searchPlace;
  String get myLocation;
  String routeDistanceKm(double km);
  String routeInfo(String distance, String duration);
  String routeSummary(double distanceKm, double durationMin);
  String get unnamedPiste;
  String stepInfo(String distance, String duration);
  String photoLocation(double lat, double lng);
  String get noGpsDataInPhoto;
  String stepDurationMinSec(int minutes, int seconds);
  String stepDurationSec(int seconds);

  // 团队相关
  String get teamSkiing;
  String get yourNickname;
  String get createNewTeam;
  String get teamName;
  String get teamNameHint;
  String get createTeam;
  String get joinExistingTeam;
  String get teamCode;
  String get teamCodeHint;
  String get joinTeam;
  String get pleaseEnterNickname;
  String get pleaseEnterTeamName;
  String get pleaseEnterTeamCode;
  String get createFailed;
  String get joinFailed;
  String get noPermissionCreateTeam;
  String get adminVerification;
  String get adminVerificationDesc;
  String get adminEmail;
  String get adminEmailHint;
  String get verify;
  String get permissionDenied;
  String teamMemberCount(int current, int max);
  String teamCodeLabel(String code);
  String get inviteLink;
  String get linkCopied;
  String get meetingPoints;
  String get shareMyLocation;
  String get shareMyLocationDesc;
  String get showMeetingPoints;
  String get showMeetingPointsDesc;
  String get teamMembers;
  String get refreshMemberLocation;
  String get refreshed;
  String maxMembersLabel(int max);
  String get leaveTeam;
  String get leaveTeamConfirm;
  String get me;
  String get sharingLocation;
  String get checkedInToday;
  String get notCheckedIn;
  String get changeNickname;
  String get newNickname;
  String get newNicknameHint;
  String get nicknameUpdated;
  String get updateFailed;
  String get removeMember;
  String removeMemberConfirm(String name);
  String get setMaxMembers;
  String maxMembersValue(int count);
  String get maxMembersFeatureNotAvailable;
  String get operationFailed;
  String get leader;
  String get location;
  String get updateTime;
  String get locate;
  String get navigateToMember;
  String planningRouteToMember(String name);
  String get cannotGetLocation;
  String secondsAgo(int seconds);
  String minutesAgo(int minutes);
  String hoursAgo(int hours);

  // 集合点
  String get meetingPoint;
  String get noMeetingPoints;
  String get noMeetingPointsHint;
  String get addMeetingPointHint;
  String createdBy(String name);
  String get setAsActive;
  String get unsetActive;
  String get setAsCurrentMeetingPoint;
  String get unsetAsCurrentMeetingPoint;
  String get editName;
  String get navigateTo;
  String get editMeetingPointName;
  String get name;
  String get deleteMeetingPoint;
  String deleteMeetingPointConfirm(String name);
  String get addMeetingPoint;
  String get meetingPointName;
  String meetingPointAdded(String name);
  String get addMeetingPointFailed;
  String meetingPointLabel(String location);

  // 雪道信息
  String get difficulty;
  String get distance;
  String get ascent;
  String get descent;
  String get avgSlope;
  String get ref;
  String get type;
  String get length;
  String get noElevationData;
  String get liftType;

  // 语言切换
  String get language;
  String get chinese;
  String get english;

  // 小红书
  String get followOnXiaohongshu;
}
