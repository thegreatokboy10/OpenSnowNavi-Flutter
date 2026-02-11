// 团队管理面板
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../config/app_theme.dart';
import '../config/team_config.dart';
import '../member/member_service.dart';
import '../team/team_models.dart';
import '../team/team_service.dart';
import '../meeting_point/meeting_point_service.dart';
import 'meeting_point_panel.dart';

class TeamPanel extends StatefulWidget {
  final String resortKey;
  final VoidCallback? onClose;
  final Function(List<MemberLocation>)? onMemberLocationsUpdate;
  final Function(MemberLocation)? onMemberTapped;
  final VoidCallback? onTeamJoined;
  final VoidCallback? onNavigateToLogin;

  const TeamPanel({
    super.key,
    required this.resortKey,
    this.onClose,
    this.onMemberLocationsUpdate,
    this.onMemberTapped,
    this.onTeamJoined,
    this.onNavigateToLogin,
  });

  @override
  State<TeamPanel> createState() => _TeamPanelState();
}

class _TeamPanelState extends State<TeamPanel> {
  final TeamService _teamService = TeamService.instance;
  final MemberService _memberService = MemberService.instance;
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _teamIdController = TextEditingController();
  int _maxMembers = TeamConfig.defaultMaxMembers; // 默认团队人数

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _teamService.initialize();

    // 设置团队更新回调
    _teamService.onTeamUpdated = (team) {
      if (mounted) {
        setState(() {});
        if (widget.onMemberLocationsUpdate != null) {
          widget.onMemberLocationsUpdate!(_teamService.getMemberLocations());
        }
      }
    };

    // 设置成员位置更新回调
    _teamService.onMembersLocationUpdate = (members) {
      if (widget.onMemberLocationsUpdate != null) {
        widget.onMemberLocationsUpdate!(_teamService.getMemberLocations());
      }
      if (mounted) setState(() {});
    };

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamIdController.dispose();
    super.dispose();
  }

  Future<void> _refreshTeam() async {
    await _teamService.refreshTeam();
    if (mounted) {
      setState(() {});
      if (widget.onMemberLocationsUpdate != null) {
        widget.onMemberLocationsUpdate!(_teamService.getMemberLocations());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _teamService.currentTeam == null
                  ? _buildNoTeamView()
                  : _buildTeamView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = S.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.panelHeaderDecoration,
      child: Row(
        children: [
          const Icon(Icons.group, color: AppTheme.panelHeaderText),
          const SizedBox(width: 8),
          Text(
            l10n.teamSkiing,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.panelHeaderText,
            ),
          ),
          const Spacer(),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.panelHeaderText),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildNoTeamView() {
    final l10n = S.of(context)!;
    // 检查是否已登录会员
    if (!_memberService.isLoggedIn) {
      return _buildLoginRequiredView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_errorMessage!,
                style: TextStyle(color: Colors.red.shade700)),
          ),

        // 显示当前会员信息
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green.shade400,
                child: Text(
                  _memberService.currentMember?.initials ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _memberService.currentMember?.name ?? l10n.member,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _memberService.isSuperAdmin || _memberService.isAdmin
                          ? l10n.admin
                          : l10n.member,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 只有 super_admin 或 admin 可以创建团队
        if (_memberService.isSuperAdmin || _memberService.isAdmin) ...[
          Text(l10n.createNewTeam,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _teamNameController,
            decoration: InputDecoration(
              labelText: l10n.teamName,
              hintText: l10n.teamNameHint,
              prefixIcon: const Icon(Icons.groups),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // 团队人数选择
          Row(
            children: [
              Text('${l10n.teamSize}: '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _maxMembers,
                items: List.generate(
                  (TeamConfig.maxMaxMembers - TeamConfig.minMaxMembers) ~/ 2 +
                      1,
                  (i) => TeamConfig.minMaxMembers + i * 2,
                )
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Text(l10n.teamSizeFormat(n)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _maxMembers = value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _createTeam,
            icon: const Icon(Icons.add),
            label: Text(l10n.createTeam),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],

        // 加入团队
        Text(l10n.joinExistingTeam,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _teamIdController,
          decoration: InputDecoration(
            labelText: l10n.teamCode,
            hintText: l10n.teamCodeHint,
            prefixIcon: const Icon(Icons.vpn_key),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _joinTeam,
          icon: const Icon(Icons.login),
          label: Text(l10n.joinTeam),
        ),
      ],
    );
  }

  /// 未登录时显示的视图
  Widget _buildLoginRequiredView() {
    final l10n = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.person_off,
                size: 48,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.loginRequired,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.teamSkiingRequiresLogin,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  widget.onNavigateToLogin?.call();
                },
                icon: const Icon(Icons.login),
                label: Text(l10n.goToLogin),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createTeam() async {
    final l10n = S.of(context)!;
    if (_teamNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.pleaseEnterTeamName);
      return;
    }

    // 权限检查已在 TeamService 中完成
    setState(() => _isLoading = true);
    try {
      final result = await _teamService.createTeam(
        name: _teamNameController.text.trim(),
        resortKey: widget.resortKey,
        maxMembers: _maxMembers,
      );
      if (result.success) {
        setState(() => _errorMessage = null);
        widget.onTeamJoined?.call();
      } else {
        setState(() => _errorMessage = result.error ?? l10n.createFailed);
      }
    } catch (e) {
      setState(() => _errorMessage = '${l10n.createFailed}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinTeam() async {
    final l10n = S.of(context)!;
    if (_teamIdController.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.pleaseEnterTeamCode);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _teamService.joinTeam(
        _teamIdController.text.trim().toUpperCase(),
      );

      if (result.success) {
        setState(() => _errorMessage = null);
        widget.onTeamJoined?.call();
      } else {
        setState(() => _errorMessage = result.error ?? l10n.joinFailed);
      }
    } catch (e) {
      setState(() => _errorMessage = '${l10n.joinFailed}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTeamView() {
    final l10n = S.of(context)!;
    final team = _teamService.currentTeam!;
    final isLeader = _teamService.isLeader;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 团队信息
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      team.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${team.members.length}/${team.maxMembers}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.teamCodeFormat(team.id),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 分享链接和集合点按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _teamService.getShareLink()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.linkCopied)),
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: Text(l10n.inviteLink),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showMeetingPointsPanel,
                icon: const Icon(Icons.star,
                    size: 18, color: AppTheme.meetingPointActiveColor),
                label: Text(l10n.meetingPoints),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.meetingPointActiveColor,
                  side:
                      const BorderSide(color: AppTheme.meetingPointActiveColor),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Divider(),

        // 成员列表标题和刷新按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(l10n.teamMembers,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh,
                      size: 20, color: Colors.blue.shade600),
                  tooltip: l10n.refreshMemberLocations,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    await _refreshTeam();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(l10n.refreshed),
                            duration: const Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ],
            ),
            if (isLeader)
              TextButton(
                onPressed: _showMaxMembersDialog,
                child: Text(l10n.membersLimit(team.maxMembers)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        ...team.members.map((member) => _buildMemberTile(member, isLeader)),

        const SizedBox(height: 16),

        // 离开团队
        TextButton.icon(
          onPressed: _leaveTeam,
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label:
              Text(l10n.leaveTeam, style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildMemberTile(TeamMember member, bool isLeader) {
    final l10n = S.of(context)!;
    final isMe = member.deviceId == _teamService.effectiveId;
    final isSharingLocation = member.isSharingLocation;
    final isLocationActive = member.isLocationActive;

    // 确定状态圆圈颜色
    Color? statusDotColor;
    if (isSharingLocation) {
      statusDotColor = isLocationActive ? Colors.green : Colors.grey;
    }

    // 状态文字
    String statusText;
    Color statusTextColor;
    if (isSharingLocation) {
      statusText =
          isLocationActive ? l10n.sharingLocation : l10n.locationSharingActive;
      statusTextColor = isLocationActive ? Colors.green : Colors.grey;
    } else if (member.shareLocation) {
      statusText = l10n.locationExpired;
      statusTextColor = Colors.grey;
    } else {
      statusText = l10n.notSharingLocation;
      statusTextColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMe ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：头像、昵称、标签、操作按钮
          Row(
            children: [
              // 头像（带状态圆圈）
              GestureDetector(
                onTap: isSharingLocation
                    ? () {
                        final memberLocation = _teamService
                            .getMemberLocationByDeviceId(member.deviceId);
                        if (memberLocation != null &&
                            widget.onMemberTapped != null) {
                          widget.onMemberTapped!(memberLocation);
                        }
                      }
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isSharingLocation
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        member.isLeader ? Icons.star : Icons.person,
                        size: 20,
                        color: isSharingLocation ? Colors.blue : Colors.grey,
                      ),
                    ),
                    // 状态圆圈（右上角）
                    if (statusDotColor != null)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusDotColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 昵称和标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.nickname,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe)
                          Text(' (${l10n.me})',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        if (member.isLeader)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(l10n.leader,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.amber)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // 操作按钮区域
              if (isMe)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onPressed: () => _showEditNicknameDialog(member.nickname),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: l10n.editNickname,
                ),
              if (isLeader)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20, color: Colors.red),
                  onPressed: () => _removeMember(member),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: l10n.removeMember,
                ),
            ],
          ),
          // 第二行：位置共享开关（仅自己可见）
          if (isMe) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 16,
                    color: member.shareLocation
                        ? AppTheme.toggleActiveColor
                        : Colors.grey),
                const SizedBox(width: 6),
                Text(l10n.shareMyLocation,
                    style: const TextStyle(fontSize: 13)),
                const Spacer(),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: member.shareLocation,
                    activeColor: AppTheme.toggleActiveColor,
                    onChanged: (value) async {
                      await _teamService.setLocationSharing(value);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showMeetingPointsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: MeetingPointPanel(
          teamId: _teamService.currentTeam!.id,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showMaxMembersDialog() {
    final l10n = S.of(context)!;
    final team = _teamService.currentTeam!;
    int newMax = team.maxMembers;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setMembersLimit),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: newMax.toDouble(),
                min: team.members.length.toDouble(),
                max: TeamConfig.maxMaxMembers.toDouble(),
                divisions: TeamConfig.maxMaxMembers - team.members.length,
                label: l10n.teamSizeFormat(newMax),
                onChanged: (v) => setDialogState(() => newMax = v.toInt()),
              ),
              Text(l10n.teamSizeFormat(newMax)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 后端 API 暂不支持直接修改 maxSize
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.featureNotAvailable)),
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveTeam() async {
    final l10n = S.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.leaveTeam),
        content: Text(l10n.leaveTeamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _teamService.leaveTeam();
      MeetingPointService.instance.clearContext();
      if (mounted) setState(() {});
    }
  }

  Future<void> _showEditNicknameDialog(String currentNickname) async {
    final l10n = S.of(context)!;
    final controller = TextEditingController(text: currentNickname);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editNickname),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.newNickname,
            hintText: l10n.enterNewNickname,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx, name);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newNickname != null && newNickname.isNotEmpty) {
      final success = await _teamService.updateNickname(newNickname);
      if (success && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.nicknameUpdated)),
        );
      }
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final l10n = S.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeMember),
        content: Text(l10n.removeMemberConfirm(member.nickname)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _teamService.removeMember(member.deviceId);
      if (mounted) setState(() {});
    }
  }
}
