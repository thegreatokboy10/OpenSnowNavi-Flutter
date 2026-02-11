import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '雪导航追踪器';

  @override
  String get tabRecord => '记录';

  @override
  String get tabMap => '地图';

  @override
  String get tabHistory => '历史';

  @override
  String get tabMe => '我的';

  @override
  String get loading => '加载中...';

  @override
  String get recordingInterrupted => '录制中断';

  @override
  String get recordingInterruptedMessage => '发现中断的录制，是否继续？';

  @override
  String started(String time) {
    return '开始时间: $time';
  }

  @override
  String duration(String duration) {
    return '持续时间: $duration';
  }

  @override
  String get discard => '放弃';

  @override
  String get continueRecording => '继续录制';

  @override
  String get sharedRouteFound => '发现分享路线';

  @override
  String get sharedRouteMessage => '检测到剪贴板中有分享的路线，是否导入？';

  @override
  String resort(String name) {
    return '雪场: $name';
  }

  @override
  String route(String origin, String destination) {
    return '路线: $origin → $destination';
  }

  @override
  String stopovers(int count) {
    return '途径点: $count个';
  }

  @override
  String get ignore => '忽略';

  @override
  String get importRoute => '导入路线';

  @override
  String get start => '开始';

  @override
  String get stop => '停止';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续';

  @override
  String get speed => '速度';

  @override
  String get altitude => '海拔';

  @override
  String get distance => '距离';

  @override
  String get maxSpeed => '最高速度';

  @override
  String get avgSpeed => '平均速度';

  @override
  String get elevationGain => '累计爬升';

  @override
  String get elevationLoss => '累计下降';

  @override
  String get noLocationData => '无位置数据';

  @override
  String get waitingForGPS => '等待GPS信号...';

  @override
  String get permissionRequired => '需要权限';

  @override
  String get alwaysLocationPermission => '后台录制轨迹需要「始终」位置访问权限。';

  @override
  String get goToSettings => '前往设置';

  @override
  String get later => '稍后';

  @override
  String get noTracksToExport => '没有可导出的轨迹';

  @override
  String get exportTracks => '导出轨迹';

  @override
  String get importTracks => '导入轨迹';

  @override
  String get deleteTrack => '删除轨迹';

  @override
  String get deleteTrackConfirm => '确定要删除这条轨迹吗？';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确定';

  @override
  String get save => '保存';

  @override
  String get close => '关闭';

  @override
  String get refresh => '刷新';

  @override
  String get share => '分享';

  @override
  String get edit => '编辑';

  @override
  String get download => '下载';

  @override
  String get downloaded => '已下载';

  @override
  String get notDownloaded => '未下载';

  @override
  String get login => '登录';

  @override
  String get logout => '退出登录';

  @override
  String get logoutConfirm => '确定要退出登录吗？';

  @override
  String get loginSuccess => '登录成功';

  @override
  String get loginFailed => '登录失败';

  @override
  String get enterEmail => '输入邮箱地址';

  @override
  String get invalidEmail => '请输入有效的邮箱地址';

  @override
  String get emptyEmail => '请输入邮箱地址';

  @override
  String get memberLogin => '会员登录';

  @override
  String get memberLoginHint => '登录以使用组队滑雪等会员功能';

  @override
  String get emailAddress => '邮箱地址';

  @override
  String get enterRegisteredEmail => '请输入注册邮箱';

  @override
  String get goToLogin => '前往登录';

  @override
  String get member => '会员';

  @override
  String get admin => '管理员';

  @override
  String get superAdmin => '超级管理员';

  @override
  String get coach => '教练';

  @override
  String get nameNotSet => '未设置姓名';

  @override
  String get memberQRCode => '会员验证二维码';

  @override
  String get scanToVerify => '扫描验证会员状态';

  @override
  String get team => '团队';

  @override
  String get teamSkiing => '组队滑雪';

  @override
  String get createTeam => '创建团队';

  @override
  String get joinTeam => '加入团队';

  @override
  String get leaveTeam => '离开团队';

  @override
  String get leaveTeamConfirm => '确定要离开当前团队吗？';

  @override
  String get teamCode => '团队代码';

  @override
  String get teamCodeHint => '输入团队代码';

  @override
  String get teamName => '团队名称';

  @override
  String get teamNameHint => '例如：SnowNavi';

  @override
  String get teamMembers => '团队成员';

  @override
  String get teamSize => '团队人数';

  @override
  String teamSizeFormat(int count) {
    return '$count人';
  }

  @override
  String teamCodeFormat(String code) {
    return '团队代码: $code';
  }

  @override
  String get shareLocation => '共享位置';

  @override
  String get shareMyLocation => '共享我的位置';

  @override
  String get nickname => '昵称';

  @override
  String get newNickname => '新昵称';

  @override
  String get enterNewNickname => '输入新的昵称';

  @override
  String get editNickname => '修改昵称';

  @override
  String get nicknameUpdated => '昵称已更新';

  @override
  String get inviteLink => '邀请链接';

  @override
  String get linkCopied => '链接已复制';

  @override
  String get createNewTeam => '创建新团队';

  @override
  String get joinExistingTeam => '加入已有团队';

  @override
  String get loginRequired => '需要登录会员';

  @override
  String get teamSkiingRequiresLogin => '组队滑雪功能需要先登录会员账号';

  @override
  String get pleaseEnterTeamName => '请输入团队名称';

  @override
  String get pleaseEnterTeamCode => '请输入团队代码';

  @override
  String get createFailed => '创建失败';

  @override
  String get joinFailed => '加入失败';

  @override
  String get refreshed => '已刷新';

  @override
  String get refreshMemberLocations => '刷新成员位置';

  @override
  String membersLimit(int count) {
    return '上限: $count人';
  }

  @override
  String get setMembersLimit => '设置成员上限';

  @override
  String get featureNotAvailable => '此功能暂不可用';

  @override
  String get sharingLocation => '正在共享位置';

  @override
  String get locationSharingActive => '位置共享中';

  @override
  String get locationExpired => '位置已过期';

  @override
  String get notSharingLocation => '未共享位置';

  @override
  String get me => '我';

  @override
  String get leader => '队长';

  @override
  String get removeMember => '移除成员';

  @override
  String removeMemberConfirm(String name) {
    return '确定要将 $name 移出团队吗？';
  }

  @override
  String get meetingPoint => '集合点';

  @override
  String get meetingPoints => '集合点';

  @override
  String get setMeetingPoint => '设置集合点';

  @override
  String get clearMeetingPoint => '清除集合点';

  @override
  String get navigateToMeetingPoint => '导航到集合点';

  @override
  String get noMeetingPoints => '暂无集合点';

  @override
  String get longPressToAddMeetingPoint => '在地图上长按可添加集合点';

  @override
  String get editMeetingPointName => '编辑集合点名称';

  @override
  String get deleteMeetingPoint => '删除集合点';

  @override
  String deleteMeetingPointConfirm(String name) {
    return '确定要删除集合点「$name」吗？';
  }

  @override
  String get setAsCurrentMeetingPoint => '设为当前集合点';

  @override
  String get cancelCurrentMeetingPoint => '取消设为当前集合点';

  @override
  String get navigateHere => '导航到此处';

  @override
  String createdBy(String name) {
    return '创建者: $name';
  }

  @override
  String get name => '名称';

  @override
  String get routePlanning => '路线规划';

  @override
  String get setOrigin => '设为起点';

  @override
  String get setDestination => '设为终点';

  @override
  String get addStopover => '添加途径点';

  @override
  String get addAsMeetingPoint => '添加为集合点';

  @override
  String get calculateRoute => '计算路线';

  @override
  String get clearRoute => '清除路线';

  @override
  String get shareRoute => '分享路线';

  @override
  String get origin => '起点';

  @override
  String get destination => '终点';

  @override
  String get stopover => '途径点';

  @override
  String stopoverNumber(int number) {
    return '途径点 $number';
  }

  @override
  String clickToSelect(String label) {
    return '点击选择$label';
  }

  @override
  String get searchOrigin => '搜索起点';

  @override
  String get searchDestination => '搜索终点';

  @override
  String searchStopover(int number) {
    return '搜索途径点 $number';
  }

  @override
  String get searchNewStopover => '搜索新途径点';

  @override
  String get searchLocation => '搜索地点';

  @override
  String get useCurrentLocation => '使用当前位置';

  @override
  String get longPressMapToSelect => '长按地图可选择任意位置';

  @override
  String get routeDetails => '路线详情';

  @override
  String get unnamedPiste => '未命名雪道';

  @override
  String get selectedLocation => '选中位置';

  @override
  String get selectResort => '选择雪场';

  @override
  String get layerSettings => '图层设置';

  @override
  String get pistesAndLifts => '雪道和缆车';

  @override
  String get showResortPistesAndLifts => '显示当前雪场的雪道和缆车数据';

  @override
  String get openSnowMap => 'OpenSnowMap';

  @override
  String get showOpenSnowMapLayer => '显示 OpenSnowMap 滑雪地图图层';

  @override
  String get teammateLocations => '队友位置';

  @override
  String get showTeammateLocations => '显示团队成员的实时位置';

  @override
  String get showMeetingPoints => '显示团队集合点';

  @override
  String get offlineMap => '离线地图';

  @override
  String get offlineDataManagement => '离线数据管理';

  @override
  String get offlineMaps => '离线地图';

  @override
  String get navigationData => '导航数据';

  @override
  String get downloadMap => '下载地图';

  @override
  String get deleteMap => '删除地图';

  @override
  String get deleteOfflineMap => '删除离线地图';

  @override
  String deleteOfflineMapConfirm(String name) {
    return '确定要删除 $name 的离线地图吗？';
  }

  @override
  String offlineMapDownloaded(String name) {
    return '$name 离线地图下载完成';
  }

  @override
  String downloadFailed(String error) {
    return '下载失败: $error';
  }

  @override
  String get downloadMapsForOffline => '下载雪场地图供离线使用';

  @override
  String get importNavFile => '导入导航文件';

  @override
  String get noNavigationData => '暂无导航数据';

  @override
  String get clickToImportSqlite => '点击上方按钮导入 .sqlite 文件';

  @override
  String get importNavDataForOffline => '导入雪场导航数据后，可使用离线路线规划';

  @override
  String get selectResortForNavFile => '选择关联雪场';

  @override
  String get navDataImportSuccess => '导航数据导入成功';

  @override
  String get importFailed => '导入失败，文件可能无效';

  @override
  String get cannotAccessFile => '无法访问文件';

  @override
  String get pleaseSelectSqliteFile => '请选择 .sqlite 格式的导航文件';

  @override
  String get deleteNavData => '删除导航数据';

  @override
  String deleteNavDataConfirm(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get units => '单位';

  @override
  String get metric => '公制';

  @override
  String get imperial => '英制';

  @override
  String get unknown => '未知';

  @override
  String get unknownResort => '未知雪场';

  @override
  String hourMinute(int hours, int minutes) {
    return '$hours小时$minutes分钟';
  }

  @override
  String minuteOnly(int minutes) {
    return '$minutes分钟';
  }

  @override
  String secondsFormat(int seconds) {
    return '$seconds秒';
  }

  @override
  String minSecFormat(int minutes, int seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String get videoExport => '导出视频';

  @override
  String get microphonePermissionNote => '需要麦克风权限才能录制视频中的声音';

  @override
  String get startExport => '开始导出';

  @override
  String get stopExport => '停止导出';

  @override
  String get exportComplete => '导出完成';

  @override
  String get exportCancelled => '已取消导出';

  @override
  String get savedToGallery => '已保存到相册';

  @override
  String get saveFailed => '保存失败';

  @override
  String get saveToGallery => '保存相册';

  @override
  String get videoOnTrack => '轨迹上的视频';

  @override
  String get fullPlayback => '完整播放';

  @override
  String get playFullVideoOnTrack => '播放轨迹上的完整视频';

  @override
  String get fixedDurationSkip => '固定时长后跳过';

  @override
  String get playFixedSecondsAndSkip => '播放固定秒数后跳过';

  @override
  String get skipMedia => '不包含视频';

  @override
  String get skipAllPhotosAndVideos => '跳过所有照片和视频';

  @override
  String get secondsUnit => '秒';

  @override
  String get rec => 'REC';

  @override
  String get unableToStartRecording => '无法启动录制';

  @override
  String get gpsNoSignal => '无GPS';

  @override
  String get gpsWeak => '弱';

  @override
  String get gpsFair => '一般';

  @override
  String get gpsGood => '良好';

  @override
  String get gpsExcellent => '优秀';

  @override
  String get statusReady => '准备就绪';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusAutoPaused => '自动暂停';

  @override
  String get statusRecording => '录制中';

  @override
  String get stopRecordingTitle => '停止录制？';

  @override
  String get stopRecordingMessage => '确定要停止本次录制吗？';

  @override
  String get history => '历史记录';

  @override
  String get dataManagement => '数据管理';

  @override
  String get exportAllTracks => '导出所有轨迹';

  @override
  String get backupToZip => '备份到 ZIP 文件并分享';

  @override
  String get importFromBackup => '从备份文件恢复';

  @override
  String get noSessionsYet => '暂无记录';

  @override
  String get startRecordingHint => '开始录制后将在此显示';

  @override
  String get totalDuration => '总时长';

  @override
  String get skiingDuration => '滑雪时长';

  @override
  String get totalDistance => '总距离';

  @override
  String get skiingDistance => '滑雪距离';

  @override
  String get deleteSession => '删除记录？';

  @override
  String get deleteSessionWarning => '此操作无法撤销。';

  @override
  String get sessionDetails => '轨迹详情';

  @override
  String get replay3D => '3D 回放';

  @override
  String get showHidePhotos => '显示/隐藏照片';

  @override
  String get exportGPX => '导出 GPX';

  @override
  String get noTrackData => '无轨迹数据';

  @override
  String get tapToShowControls => '点击屏幕显示控制面板';

  @override
  String get skip => '跳过';

  @override
  String get failedToExportGPX => 'GPX 导出失败';

  @override
  String get unableToGetCurrentLocation => '无法获取当前位置';

  @override
  String get currentLocation => '当前位置';

  @override
  String get pleaseJoinOrCreateTeam => '请先加入或创建团队';

  @override
  String get addMeetingPoint => '添加集合点';

  @override
  String get meetingPointName => '集合点名称';

  @override
  String get enterMeetingPointName => '请输入集合点名称';

  @override
  String meetingPointAdded(String name) {
    return '集合点「$name」已添加';
  }

  @override
  String addMeetingPointFailed(String error) {
    return '添加集合点失败: $error';
  }

  @override
  String get downloadOfflineMaps => '下载雪场地图供离线使用';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours小时前';
  }

  @override
  String locationUpdatedAt(String time) {
    return '位置更新于$time';
  }

  @override
  String get planRouteToMember => '规划路线到 TA';

  @override
  String get activeMeetingPoint => '当前活动集合点';

  @override
  String get planRoute => '规划路线';

  @override
  String get setAsActive => '设为活动';

  @override
  String get chairLift => '吊椅缆车';

  @override
  String get gondolaLift => '厢式缆车';

  @override
  String get cableCar => '索道';

  @override
  String get dragLift => '拖牵';

  @override
  String get magicCarpet => '魔毯';

  @override
  String get lift => '缆车';

  @override
  String get noviceDifficulty => '初级';

  @override
  String get easyDifficulty => '中级';

  @override
  String get intermediateDifficulty => '高级';

  @override
  String get advancedDifficulty => '专家';

  @override
  String get expertDifficulty => '专家';

  @override
  String get freerideDifficulty => '野雪';

  @override
  String get shareGpxText => '滑雪轨迹 GPX';

  @override
  String get confirmFilter => '确认筛选';

  @override
  String filteredMediaCount(int count) {
    return '已筛选 $count 个媒体';
  }

  @override
  String get speedFast => '快速 (15s)';

  @override
  String get speedNormal => '标准 (30s)';

  @override
  String get speedSlow => '慢速 (45s)';

  @override
  String get reset => '重置';

  @override
  String get presets => '预设';

  @override
  String get saveSettings => '保存设置';

  @override
  String get done => '完成';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get emailOpenedAddAttachment => '邮件已打开，请手动添加附件';

  @override
  String get shareToOtherApps => '分享到其他应用';

  @override
  String get wechatQQEtc => '微信、QQ 等';

  @override
  String get copyShareText => '复制分享文本';

  @override
  String get copyShareTextHint => '对方复制后打开 App 自动加载';

  @override
  String get feedbackRouteProblem => '反馈路线问题';

  @override
  String sendToEmail(String email) {
    return '发送至 $email';
  }

  @override
  String get routeShareTextCopied => '路线分享文本已复制';

  @override
  String get replayDuration => '回放时长';

  @override
  String get cameraZoom => '相机缩放';

  @override
  String get cameraTilt => '相机倾斜';

  @override
  String get lookAheadPoints => '前瞻点数';

  @override
  String get directionSmoothing => '方向平滑';

  @override
  String get photoDuration => '照片展示时长';

  @override
  String get shareAttachment => '分享附件';

  @override
  String get replaySettings => '回放设置';

  @override
  String get mediaPlayback => '媒体播放';

  @override
  String get showMediaDuringReplay => '回放时展示照片/视频';

  @override
  String get showMediaDuringReplayHint => '轨迹经过媒体位置时自动环绕展示';

  @override
  String get unitSeconds => '秒';

  @override
  String get unitPoints => '点';

  @override
  String get fast => '快速';

  @override
  String get normal => '标准';

  @override
  String get slow => '慢速';
}
