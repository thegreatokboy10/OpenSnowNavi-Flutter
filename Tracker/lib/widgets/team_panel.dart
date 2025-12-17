// 团队管理面板
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
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

  const TeamPanel({
    super.key,
    required this.resortKey,
    this.onClose,
    this.onMemberLocationsUpdate,
    this.onMemberTapped,
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
          decoration: const InputDecoration(
            labelText: '你的昵称',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // 创建团队
        const Text('创建新团队', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _teamNameController,
          decoration: const InputDecoration(
            labelText: '团队名称',
            hintText: '例如：快乐滑雪队',
            prefixIcon: Icon(Icons.groups),
            border: OutlineInputBorder(),
          ),
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

        // 加入团队
        const Text('加入已有团队', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _teamIdController,
          decoration: const InputDecoration(
            labelText: '团队代码',
            hintText: '输入6位团队代码',
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

  Future<void> _createTeam() async {
    if (_nicknameController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入昵称');
      return;
    }
    if (_teamNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入团队名称');
      return;
    }

    // 弹窗要求输入管理员邮箱进行权限验证
    final email = await _showAdminEmailDialog();
    if (email == null || email.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 验证权限
      final permissionResult = await _teamService.checkPermission(email);
      if (!permissionResult.isSuperAdmin) {
        setState(() {
          _errorMessage = '没有创建团队的权限';
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

  Future<String?> _showAdminEmailDialog() async {
    final emailController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('管理员验证'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('创建团队需要管理员权限，请输入管理员邮箱进行验证'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '管理员邮箱',
                hintText: 'admin@example.com',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
            child: const Text('验证'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinTeam() async {
    if (_nicknameController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入昵称');
      return;
    }
    if (_teamIdController.text.trim().isEmpty) {
      setState(() => _errorMessage = '请输入团队代码');
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

        // 位置共享开关
        if (currentMember != null)
          SwitchListTile(
            title: const Text('共享我的位置'),
            subtitle: const Text('让队友看到你的实时位置'),
            value: currentMember.shareLocation,
            onChanged: (value) async {
              await _teamService.setLocationSharing(value);
              setState(() {});
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
    final isMe = member.deviceId == _teamService.deviceId;
    final isActive = member.hasCheckedInToday;
    final hasLocation = member.shareLocation && member.lastLocation != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: hasLocation
          ? () {
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
          if (isMe) const Text(' (我)', style: TextStyle(color: Colors.grey)),
          if (member.isLeader)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified, size: 16, color: Colors.amber),
            ),
          if (hasLocation)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.location_on, size: 16, color: Colors.blue),
            ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: () => _showEditNicknameDialog(member.nickname),
                child: const Icon(Icons.edit, size: 16, color: Colors.grey),
              ),
            ),
        ],
      ),
      subtitle: Text(
        isActive ? (member.shareLocation ? '正在共享位置' : '今日已签到') : '未签到',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: isLeader && !isMe
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _removeMember(member),
            )
          : null,
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
                max: 20,
                divisions: 20 - team.members.length,
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
