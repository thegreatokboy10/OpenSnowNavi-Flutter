import 'app_strings.dart';

/// 中文字符串实现
class StringsZh implements AppStrings {
  // 通用
  @override
  String get appName => 'SnowNavi指雪针';
  @override
  String get appTitle => '智能滑雪路线规划 | SnowNavi指雪针';
  @override
  String get ok => '确定';
  @override
  String get cancel => '取消';
  @override
  String get save => '保存';
  @override
  String get delete => '删除';
  @override
  String get close => '关闭';
  @override
  String get refresh => '刷新';
  @override
  String get loading => '加载中...';
  @override
  String get error => '错误';
  @override
  String get unknown => '未知';
  @override
  String get confirm => '确定';
  @override
  String get add => '添加';
  @override
  String get followMeOnSocialMedia => '关注我的小红书 @了不起的okboy';

  // 地图相关
  @override
  String get loadingMap => '正在加载地图...';
  @override
  String get filter => '筛选';
  @override
  String get filterPistes => '筛选雪道';
  @override
  String get locateMe => '定位';
  @override
  String get share => '分享';
  @override
  String get layers => '图层';
  @override
  String get mapLayers => '地图图层';
  @override
  String get openSnowMap => 'OpenSnowMap';
  @override
  String get openSnowMapDesc => '显示全球雪场图层';
  @override
  String get searchPoi => '搜索地点';
  @override
  String get noResults => '未找到结果';
  @override
  String get openPhoto => '打开图片';
  @override
  String get select => '选择';

  // 难度级别
  @override
  String get difficultyNovice => '初学者';
  @override
  String get difficultyEasy => '简单';
  @override
  String get difficultyIntermediate => '中级';
  @override
  String get difficultyAdvanced => '高级';
  @override
  String get difficultyExpert => '专家';
  @override
  String get difficultyFreeride => '野雪';
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

  // 2D/3D 切换
  @override
  String get mode2D => '2D';
  @override
  String get mode3D => '3D';
  @override
  String headingLabel(String heading) => '朝向: $heading';

  // 路线规划
  @override
  String get routePlanning => '路线规划';
  @override
  String get origin => '起点';
  @override
  String get destination => '终点';
  @override
  String get stopover => '途径点';
  @override
  String stopoverN(int n) => '途径点 $n';
  @override
  String get addStopover => '添加途径点';
  @override
  String get setAsOrigin => '设为起点';
  @override
  String get setAsDestination => '设为终点';
  @override
  String get setAsStopover => '设为途径点';
  @override
  String get addAsStopover => '添加途径点';
  @override
  String get route => '路线';
  @override
  String get routeDetails => '路线详情';
  @override
  String get searchOrigin => '搜索起点';
  @override
  String get searchDestination => '搜索终点';
  @override
  String searchStopoverN(int n) => '搜索途径点 $n';
  @override
  String get searchNewStopover => '搜索新途径点';
  @override
  String get clickToSelect => '点击选择';
  @override
  String clickToSelectLabel(String label) => '点击选择$label';
  @override
  String originWithCoords(String coords) => '起点 ($coords)';
  @override
  String destinationWithCoords(String coords) => '终点 ($coords)';
  @override
  String stopoverWithCoords(int n, String coords) => '途径点 $n ($coords)';
  @override
  String get currentLocation => '当前位置';
  @override
  String get fromPhoto => '从图片';
  @override
  String get searchPlace => '搜索地点...';
  @override
  String get myLocation => '我的位置';
  @override
  String routeDistanceKm(double km) => '${km.toStringAsFixed(1)}km';
  @override
  String routeInfo(String distance, String duration) =>
      '$distance • $duration 分钟';
  @override
  String routeSummary(double distanceKm, double durationMin) =>
      '${distanceKm.toStringAsFixed(2)} km • ${durationMin.toStringAsFixed(0)} 分钟';
  @override
  String get unnamedPiste => '未命名雪道';
  @override
  String stepInfo(String distance, String duration) => '$distance • $duration';
  @override
  String photoLocation(double lat, double lng) =>
      '图片位置 (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  @override
  String get noGpsDataInPhoto => '无法从图片中读取位置信息，请尝试其他图片';
  @override
  String stepDurationMinSec(int minutes, int seconds) => '$minutes分${seconds}秒';
  @override
  String stepDurationSec(int seconds) => '$seconds秒';

  // 团队相关
  @override
  String get teamSkiing => '组队滑雪';
  @override
  String get yourNickname => '你的昵称';
  @override
  String get createNewTeam => '创建新团队';
  @override
  String get teamName => '团队名称';
  @override
  String get teamNameHint => '例如：周末滑雪小分队';
  @override
  String get createTeam => '创建团队';
  @override
  String get joinExistingTeam => '加入已有团队';
  @override
  String get teamCode => '团队代码';
  @override
  String get teamCodeHint => '输入6位团队代码';
  @override
  String get joinTeam => '加入团队';
  @override
  String get pleaseEnterNickname => '请输入昵称';
  @override
  String get pleaseEnterTeamName => '请输入团队名称';
  @override
  String get pleaseEnterTeamCode => '请输入团队代码';
  @override
  String get createFailed => '创建失败';
  @override
  String get joinFailed => '加入失败';
  @override
  String get noPermissionCreateTeam => '权限不足：只有超级管理员才能创建团队';
  @override
  String get adminVerification => '管理员验证';
  @override
  String get adminVerificationDesc => '创建团队需要管理员权限，请输入您的管理员邮箱：';
  @override
  String get adminEmail => '管理员邮箱';
  @override
  String get adminEmailHint => 'admin@example.com';
  @override
  String get verify => '验证';
  @override
  String get permissionDenied => '权限不足：只有超级管理员才能创建团队';
  @override
  String teamMemberCount(int current, int max) => '$current/$max人';
  @override
  String teamCodeLabel(String code) => '团队代码: $code';
  @override
  String get inviteLink => '邀请链接';
  @override
  String get linkCopied => '链接已复制';
  @override
  String get meetingPoints => '集合点';
  @override
  String get shareMyLocation => '共享我的位置';
  @override
  String get shareMyLocationDesc => '让队友看到你的实时位置';
  @override
  String get showMeetingPoints => '显示集合点';
  @override
  String get showMeetingPointsDesc => '在地图上显示所有收藏的集合点';
  @override
  String get teamMembers => '团队成员';
  @override
  String get refreshMemberLocation => '刷新成员位置';
  @override
  String get refreshed => '已刷新';
  @override
  String maxMembersLabel(int max) => '人数上限: $max';
  @override
  String get leaveTeam => '离开团队';
  @override
  String get leaveTeamConfirm => '确定要离开当前团队吗？';
  @override
  String get me => '我';
  @override
  String get sharingLocation => '位置共享中';
  @override
  String get checkedInToday => '今日已签到';
  @override
  String get notCheckedIn => '未签到';
  @override
  String get changeNickname => '修改昵称';
  @override
  String get newNickname => '新昵称';
  @override
  String get newNicknameHint => '请输入新昵称';
  @override
  String get nicknameUpdated => '昵称已更新';
  @override
  String get updateFailed => '更新失败，请重试';
  @override
  String get removeMember => '移除成员';
  @override
  String removeMemberConfirm(String name) => '确定要移除 $name 吗？';
  @override
  String get setMaxMembers => '设置人数上限';
  @override
  String maxMembersValue(int count) => '$count人';
  @override
  String get maxMembersFeatureNotAvailable => '人数上限修改功能暂未开放';
  @override
  String get operationFailed => '操作失败，请重试';
  @override
  String get leader => '队长';
  @override
  String get location => '位置';
  @override
  String get updateTime => '更新时间';
  @override
  String get locate => '定位';
  @override
  String get navigateToMember => '导航到TA';
  @override
  String planningRouteToMember(String name) => '正在规划到 $name 的路线...';
  @override
  String get cannotGetLocation => '无法获取当前位置，请确保已开启位置权限';
  @override
  String secondsAgo(int seconds) => '${seconds}秒前';
  @override
  String minutesAgo(int minutes) => '${minutes}分钟前';
  @override
  String hoursAgo(int hours) => '${hours}小时前';

  // 集合点
  @override
  String get meetingPoint => '集合点';
  @override
  String get noMeetingPoints => '暂无集合点';
  @override
  String get noMeetingPointsHint => '在地图上选择位置后点击"添加集合点"来添加';
  @override
  String get addMeetingPointHint => '在地图上选择位置后点击"添加集合点"来添加';
  @override
  String createdBy(String name) => '由 $name 创建';
  @override
  String get setAsActive => '设为当前集合点';
  @override
  String get unsetActive => '取消设为当前集合点';
  @override
  String get setAsCurrentMeetingPoint => '设为当前集合点';
  @override
  String get unsetAsCurrentMeetingPoint => '取消设为当前集合点';
  @override
  String get editName => '编辑名称';
  @override
  String get navigateTo => '导航到此处';
  @override
  String get editMeetingPointName => '编辑集合点名称';
  @override
  String get name => '名称';
  @override
  String get deleteMeetingPoint => '删除集合点';
  @override
  String deleteMeetingPointConfirm(String name) => '确定要删除集合点 "$name" 吗？';
  @override
  String get addMeetingPoint => '添加集合点';
  @override
  String get meetingPointName => '集合点名称';
  @override
  String meetingPointAdded(String name) => '集合点 "$name" 已添加';
  @override
  String get addMeetingPointFailed => '添加集合点失败';
  @override
  String meetingPointLabel(String location) => '集合点 $location';

  // 雪道信息
  @override
  String get difficulty => '难度';
  @override
  String get distance => '距离';
  @override
  String get ascent => '上升';
  @override
  String get descent => '下降';
  @override
  String get avgSlope => '平均坡度';
  @override
  String get ref => '编号';
  @override
  String get type => '类型';
  @override
  String get length => '长度';
  @override
  String get noElevationData => '无海拔数据';
  @override
  String get liftType => '缆车类型';

  // 语言切换
  @override
  String get language => '语言';
  @override
  String get chinese => '中文';
  @override
  String get english => 'English';

  // 小红书
  @override
  String get followOnXiaohongshu => '关注我的小红书 @了不起的okboy';
}
