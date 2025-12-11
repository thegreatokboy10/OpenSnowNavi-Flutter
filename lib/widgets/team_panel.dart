// 团队管理面板
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../team/team_models.dart';
import '../team/team_service.dart';
import '../timer_flag.dart';
import '../l10n/locale_service.dart';
import 'meeting_point_panel.dart';

class TeamPanel extends StatefulWidget {
  final String resortKey;
  final VoidCallback? onClose;
  final Function(List<MemberLocation>)? onMemberLocationsUpdate;
  final Function(MemberLocation)? onMemberTapped; // 成员点击回调
  final Function(bool)? onShowMeetingPointsLayerChanged; // 集合点图层显示回调
  final VoidCallback? onTeamJoined; // 团队加入成功回调，用于初始化集合点服务
  final TimerFlag timerFlag;

  const TeamPanel({
    super.key,
    required this.resortKey,
    required this.timerFlag,
    this.onClose,
    this.onMemberLocationsUpdate,
    this.onMemberTapped,
    this.onShowMeetingPointsLayerChanged,
    this.onTeamJoined,
  });

  @override
  State<TeamPanel> createState() => _TeamPanelState();
}

class _TeamPanelState extends State<TeamPanel> {
  final TeamService _teamService = TeamService.instance;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _teamIdController = TextEditingController();

  bool _isLoading = true;
  bool _showMeetingPointsLayer = true; // 是否显示集合点图层
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _teamService.initialize();

    // 设置团队更新回调 - 当团队数据变化时刷新 UI
    _teamService.onTeamUpdated = (team) {
      if (mounted) {
        setState(() {});
        // 同时通知地图更新成员位置
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

    // 设置默认昵称
    final member = _teamService.currentMember;
    if (member != null) {
      _nicknameController.text = member.nickname;
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _teamNameController.dispose();
    _teamIdController.dispose();
    super.dispose();
  }

  /// 手动刷新团队数据
  Future<void> _refreshTeam() async {
    await _teamService.refreshTeam();
    if (mounted) {
      setState(() {});
      // 通知地图更新成员位置
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
      width: 320,
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
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Text(
            LocaleService.S.teamSkiing,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const Spacer(),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                widget.timerFlag.flag = true;
                widget.onClose!();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildNoTeamView() {
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

        TextField(
          controller: _nicknameController,
          onTap: () => widget.timerFlag.flag = true,
          decoration: InputDecoration(
            labelText: LocaleService.S.yourNickname,
            prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // 创建团队
        Text(LocaleService.S.createNewTeam,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _teamNameController,
          onTap: () => widget.timerFlag.flag = true,
          decoration: InputDecoration(
            labelText: LocaleService.S.teamName,
            hintText: LocaleService.S.teamNameHint,
            prefixIcon: const Icon(Icons.groups),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            widget.timerFlag.flag = true;
            _createTeam();
          },
          icon: const Icon(Icons.add),
          label: Text(LocaleService.S.createTeam),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // 加入团队
        Text(LocaleService.S.joinExistingTeam,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _teamIdController,
          onTap: () => widget.timerFlag.flag = true,
          decoration: InputDecoration(
            labelText: LocaleService.S.teamCode,
            hintText: LocaleService.S.teamCodeHint,
            prefixIcon: const Icon(Icons.vpn_key),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            widget.timerFlag.flag = true;
            _joinTeam();
          },
          icon: const Icon(Icons.login),
          label: Text(LocaleService.S.joinTeam),
        ),
      ],
    );
  }

  Future<void> _createTeam() async {
    if (_nicknameController.text.trim().isEmpty) {
      setState(() => _errorMessage = LocaleService.S.pleaseEnterNickname);
      return;
    }
    if (_teamNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = LocaleService.S.pleaseEnterTeamName);
      return;
    }

    // 弹窗要求输入管理员邮箱进行权限验证
    final email = await _showAdminEmailDialog();
    if (email == null || email.isEmpty) {
      return; // 用户取消
    }

    setState(() => _isLoading = true);
    try {
      // 验证权限
      final permissionResult = await _teamService.checkPermission(email);
      if (!permissionResult.isSuperAdmin) {
        setState(() {
          _errorMessage = LocaleService.S.noPermissionCreateTeam;
          _isLoading = false;
        });
        return;
      }

      final result = await _teamService.createTeam(
        name: _teamNameController.text.trim(),
        resortKey: widget.resortKey,
        nickname: _nicknameController.text.trim(),
      );
      if (result.success) {
        setState(() => _errorMessage = null);
        // 通知父组件初始化集合点服务
        widget.onTeamJoined?.call();
      } else {
        setState(
            () => _errorMessage = result.error ?? LocaleService.S.createFailed);
      }
    } catch (e) {
      setState(() => _errorMessage = '${LocaleService.S.createFailed}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 显示管理员邮箱输入弹窗
  Future<String?> _showAdminEmailDialog() async {
    final emailController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleService.S.adminVerification),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LocaleService.S.adminVerificationDesc),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              onTap: () => widget.timerFlag.flag = true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: LocaleService.S.adminEmail,
                hintText: 'admin@example.com',
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.timerFlag.flag = true;
              Navigator.pop(ctx, null);
            },
            child: Text(LocaleService.S.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              widget.timerFlag.flag = true;
              Navigator.pop(ctx, emailController.text.trim());
            },
            child: Text(LocaleService.S.verify),
          ),
        ],
      ),
    );
  }

  Future<void> _joinTeam() async {
    if (_nicknameController.text.trim().isEmpty) {
      setState(() => _errorMessage = LocaleService.S.pleaseEnterNickname);
      return;
    }
    if (_teamIdController.text.trim().isEmpty) {
      setState(() => _errorMessage = LocaleService.S.pleaseEnterTeamCode);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _teamService.joinTeam(
        _teamIdController.text.trim().toUpperCase(),
        nickname: _nicknameController.text.trim(),
      );

      if (result.success) {
        setState(() => _errorMessage = null);
        // 通知父组件初始化集合点服务
        widget.onTeamJoined?.call();
      } else {
        setState(
            () => _errorMessage = result.error ?? LocaleService.S.joinFailed);
      }
    } catch (e) {
      setState(() => _errorMessage = '${LocaleService.S.joinFailed}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTeamView() {
    final team = _teamService.currentTeam!;
    final isLeader = _teamService.isLeader;
    final currentMember = _teamService.currentMember;

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
                      LocaleService.S.teamMemberCount(
                          team.members.length, team.maxMembers),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                LocaleService.S.teamCodeLabel(team.id),
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
                  widget.timerFlag.flag = true;
                  Clipboard.setData(
                      ClipboardData(text: _teamService.getShareLink()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(LocaleService.S.linkCopied)),
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: Text(LocaleService.S.inviteLink),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.timerFlag.flag = true;
                  _showMeetingPointsPanel();
                },
                icon:
                    const Icon(Icons.star, size: 18, color: Colors.deepOrange),
                label: Text(LocaleService.S.meetingPoints),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  side: const BorderSide(color: Colors.deepOrange),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 位置共享开关
        if (currentMember != null)
          SwitchListTile(
            title: Text(LocaleService.S.shareMyLocation),
            subtitle: Text(LocaleService.S.shareMyLocationDesc),
            value: currentMember.shareLocation,
            onChanged: (value) async {
              widget.timerFlag.flag = true;
              await _teamService.setLocationSharing(value);
              setState(() {});
            },
            contentPadding: EdgeInsets.zero,
          ),

        // 集合点图层开关
        SwitchListTile(
          title: Text(LocaleService.S.showMeetingPoints),
          subtitle: Text(LocaleService.S.showMeetingPointsDesc),
          value: _showMeetingPointsLayer,
          activeColor: Colors.deepOrange,
          onChanged: (value) {
            widget.timerFlag.flag = true;
            setState(() {
              _showMeetingPointsLayer = value;
            });
            widget.onShowMeetingPointsLayerChanged?.call(value);
          },
          contentPadding: EdgeInsets.zero,
        ),

        const Divider(),

        // 成员列表标题和刷新按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(LocaleService.S.teamMembers,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                // 刷新按钮
                IconButton(
                  icon: Icon(Icons.refresh,
                      size: 20, color: Colors.blue.shade600),
                  tooltip: LocaleService.S.refreshMemberLocation,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    widget.timerFlag.flag = true;
                    await _refreshTeam();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(LocaleService.S.refreshed),
                            duration: const Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ],
            ),
            if (isLeader)
              TextButton(
                onPressed: () {
                  widget.timerFlag.flag = true;
                  _showMaxMembersDialog();
                },
                child: Text(LocaleService.S.maxMembersLabel(team.maxMembers)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        ...team.members.map((member) => _buildMemberTile(member, isLeader)),

        const SizedBox(height: 16),

        // 离开团队
        TextButton.icon(
          onPressed: () {
            widget.timerFlag.flag = true;
            _leaveTeam();
          },
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label: Text(LocaleService.S.leaveTeam,
              style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildMemberTile(TeamMember member, bool isLeader) {
    final isMe = member.deviceId == _teamService.deviceId;
    final isActive = member.hasCheckedInToday;
    final hasLocation = member.shareLocation && member.lastLocation != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: hasLocation
          ? () {
              widget.timerFlag.flag = true;
              // 获取成员位置信息并调用回调
              final memberLocation =
                  _teamService.getMemberLocationByDeviceId(member.deviceId);
              if (memberLocation != null && widget.onMemberTapped != null) {
                widget.onMemberTapped!(memberLocation);
              }
            }
          : null,
      leading: CircleAvatar(
        backgroundColor:
            isActive ? Colors.green.shade100 : Colors.grey.shade200,
        child: Icon(
          member.isLeader ? Icons.star : Icons.person,
          color: isActive ? Colors.green : Colors.grey,
        ),
      ),
      title: Row(
        children: [
          Text(member.nickname),
          if (isMe)
            Text(' (${LocaleService.S.me})',
                style: const TextStyle(color: Colors.grey)),
          if (member.isLeader)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified, size: 16, color: Colors.amber),
            ),
          // 如果有位置，显示定位图标
          if (hasLocation)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.location_on, size: 16, color: Colors.blue),
            ),
          // 自己可以编辑昵称
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: () {
                  widget.timerFlag.flag = true;
                  _showEditNicknameDialog(member.nickname);
                },
                child: const Icon(Icons.edit, size: 16, color: Colors.grey),
              ),
            ),
        ],
      ),
      subtitle: Text(
        isActive
            ? (member.shareLocation
                ? LocaleService.S.sharingLocation
                : LocaleService.S.checkedInToday)
            : LocaleService.S.notCheckedIn,
        style: TextStyle(
          color: isActive ? Colors.green : Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: isLeader && !isMe
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () {
                widget.timerFlag.flag = true;
                _removeMember(member);
              },
            )
          : null,
    );
  }

  /// 显示编辑昵称对话框
  Future<void> _showEditNicknameDialog(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);

    final newNickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleService.S.changeNickname),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: LocaleService.S.newNickname,
            hintText: LocaleService.S.newNicknameHint,
          ),
          autofocus: true,
          onTap: () => widget.timerFlag.flag = true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.timerFlag.flag = true;
              Navigator.pop(ctx);
            },
            child: Text(LocaleService.S.cancel),
          ),
          TextButton(
            onPressed: () {
              widget.timerFlag.flag = true;
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx, name);
              }
            },
            child: Text(LocaleService.S.confirm),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newNickname != null && newNickname.isNotEmpty) {
      final success = await _teamService.updateNickname(newNickname);
      if (success) {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleService.S.nicknameUpdated)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleService.S.updateFailed)),
          );
        }
      }
    }
  }

  void _removeMember(TeamMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleService.S.removeMember),
        content: Text(LocaleService.S.removeMemberConfirm(member.nickname)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleService.S.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _teamService.removeMember(member.deviceId);
              setState(() {});
            },
            child: Text(LocaleService.S.confirm,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMaxMembersDialog() {
    final team = _teamService.currentTeam!;
    int newMax = team.maxMembers;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleService.S.setMaxMembers),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: newMax.toDouble(),
                min: team.members.length.toDouble(),
                max: 20,
                divisions: 20 - team.members.length,
                label: LocaleService.S.maxMembersValue(newMax),
                onChanged: (v) => setDialogState(() => newMax = v.toInt()),
              ),
              Text(LocaleService.S.maxMembersValue(newMax)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleService.S.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 注意：后端 API 暂不支持直接修改 maxSize，需要后端添加此功能
              // 目前仅更新本地显示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(LocaleService.S.maxMembersFeatureNotAvailable)),
              );
            },
            child: Text(LocaleService.S.confirm),
          ),
        ],
      ),
    );
  }

  void _leaveTeam() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleService.S.leaveTeam),
        content: Text(LocaleService.S.leaveTeamConfirm),
        actions: [
          TextButton(
            onPressed: () {
              widget.timerFlag.flag = true;
              Navigator.pop(ctx);
            },
            child: Text(LocaleService.S.cancel),
          ),
          TextButton(
            onPressed: () async {
              widget.timerFlag.flag = true;
              Navigator.pop(ctx);
              final success = await _teamService.leaveTeam();
              if (success) {
                if (mounted) {
                  setState(() {});
                  // 通知地图清除标记
                  if (widget.onMemberLocationsUpdate != null) {
                    widget.onMemberLocationsUpdate!([]);
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(LocaleService.S.operationFailed)),
                  );
                }
              }
            },
            child: Text(LocaleService.S.confirm,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 显示集合点面板
  void _showMeetingPointsPanel() {
    widget.timerFlag.flag = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MeetingPointPanel(
        timerFlag: widget.timerFlag,
        onClose: () {
          widget.timerFlag.flag = true;
          Navigator.pop(context);
        },
        onPointTapped: (point) {
          widget.timerFlag.flag = true;
          Navigator.pop(context);
          // 通知父组件定位到集合点
          widget.onMemberTapped?.call(MemberLocation(
            deviceId: 'meeting_point_${point.id}',
            nickname: point.name,
            location: point.latLng,
            colorIndex: 0,
          ));
        },
        onNavigate: (point) {
          widget.timerFlag.flag = true;
          Navigator.pop(context);
          // 通知父组件导航到集合点
          widget.onMemberTapped?.call(MemberLocation(
            deviceId: 'meeting_point_${point.id}',
            nickname: point.name,
            location: point.latLng,
            colorIndex: 0,
          ));
        },
      ),
    );
  }
}
