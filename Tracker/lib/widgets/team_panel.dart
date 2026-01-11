// 团队管理面板
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.panelHeaderDecoration,
      child: Row(
        children: [
          const Icon(Icons.group, color: AppTheme.panelHeaderText),
          const SizedBox(width: 8),
          const Text(
            '组队滑雪',
            style: TextStyle(
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
                      _memberService.currentMember?.name ?? '会员',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _memberService.isSuperAdmin || _memberService.isAdmin
                          ? '管理员'
                          : '会员',
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
          const Text('创建新团队', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _teamNameController,
            decoration: const InputDecoration(
              labelText: '团队名称',
              hintText: '例如：SnowNavi',
              prefixIcon: Icon(Icons.groups),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // 团队人数选择
          Row(
            children: [
              const Text('团队人数: '),
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
                          child: Text('$n 人'),
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
            label: const Text('创建团队'),
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
        const Text('加入已有团队', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _teamIdController,
          decoration: const InputDecoration(
            labelText: '团队代码',
            hintText: '输入团队代码',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _joinTeam,
          icon: const Icon(Icons.login),
          label: const Text('加入团队'),
        ),
      ],
    );
  }

  /// 未登录时显示的视图
  Widget _buildLoginRequiredView() {
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
              const Text(
                '需要登录会员',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '组队滑雪功能需要先登录会员账号',
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
                label: const Text('前往登录'),
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
    if (_teamNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入团队名称');
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
        setState(() => _errorMessage = result.error ?? '创建失败');
      }
    } catch (e) {
      setState(() => _errorMessage = '创建失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinTeam() async {
    if (_teamIdController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入团队代码');
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
        setState(() => _errorMessage = result.error ?? '加入失败');
      }
    } catch (e) {
      setState(() => _errorMessage = '加入失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTeamView() {
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
                      '${team.members.length}/${team.maxMembers}人',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '团队代码: ${team.id}',
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
                    const SnackBar(content: Text('链接已复制')),
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('邀请链接'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showMeetingPointsPanel,
                icon: Icon(Icons.star,
                    size: 18, color: AppTheme.meetingPointActiveColor),
                label: const Text('集合点'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.meetingPointActiveColor,
                  side: BorderSide(color: AppTheme.meetingPointActiveColor),
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
                const Text('团队成员',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh,
                      size: 20, color: Colors.blue.shade600),
                  tooltip: '刷新成员位置',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    await _refreshTeam();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('已刷新'),
                            duration: Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ],
            ),
            if (isLeader)
              TextButton(
                onPressed: _showMaxMembersDialog,
                child: Text('上限: ${team.maxMembers}人'),
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
          label: const Text('离开团队', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildMemberTile(TeamMember member, bool isLeader) {
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
      statusText = isLocationActive ? '正在共享位置' : '位置共享中';
      statusTextColor = isLocationActive ? Colors.green : Colors.grey;
    } else if (member.shareLocation) {
      statusText = '位置已过期';
      statusTextColor = Colors.grey;
    } else {
      statusText = '未共享位置';
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
                          const Text(' (我)',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
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
                              child: const Text('队长',
                                  style: TextStyle(
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
                  tooltip: '修改昵称',
                ),
              if (isLeader)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      size: 20, color: Colors.red),
                  onPressed: () => _removeMember(member),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '移除成员',
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
                const Text('共享我的位置', style: TextStyle(fontSize: 13)),
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
    final team = _teamService.currentTeam!;
    int newMax = team.maxMembers;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置成员上限'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: newMax.toDouble(),
                min: team.members.length.toDouble(),
                max: TeamConfig.maxMaxMembers.toDouble(),
                divisions: TeamConfig.maxMaxMembers - team.members.length,
                label: '$newMax人',
                onChanged: (v) => setDialogState(() => newMax = v.toInt()),
              ),
              Text('$newMax人'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 后端 API 暂不支持直接修改 maxSize
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('此功能暂不可用')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('离开团队'),
        content: const Text('确定要离开当前团队吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
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
    final controller = TextEditingController(text: currentNickname);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新昵称',
            hintText: '输入新的昵称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx, name);
              }
            },
            child: const Text('确定'),
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
          const SnackBar(content: Text('昵称已更新')),
        );
      }
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要将 ${member.nickname} 移出团队吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
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
