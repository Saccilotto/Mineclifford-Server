/**
 * Mineclifford Dashboard Manager
 * Handles UI logic and state management
 */
class Dashboard {
    constructor() {
        this.api = new MinecliffordAPI();
        this.servers = [];
        this.pollInterval = null;
        this.pollDelay = 5000; // 5 seconds
        this.cloudDeploy = new CloudDeploymentManager();
    }

    /**
     * Initialize the dashboard
     */
    async init() {
        try {
            await this.checkBackendHealth();
            await this.refresh();
            this.setupEventListeners();
            this.startPolling();
            this.showNotification('Dashboard loaded successfully', 'success');
        } catch (error) {
            console.error('Failed to initialize dashboard:', error);
            this.showNotification('Failed to connect to backend. Make sure the API is running on port 8000.', 'error');
        }
    }

    /**
     * Check if backend is healthy
     */
    async checkBackendHealth() {
        const health = await this.api.getHealth();
        console.log('Backend health:', health);
    }

    /**
     * Refresh servers list and stats
     */
    async refresh() {
        try {
            this.servers = await this.api.getServers();
            this.render();
            this.updateStats();
        } catch (error) {
            console.error('Failed to load servers:', error);
            this.showNotification('Failed to load servers: ' + error.message, 'error');
        }
    }

    /**
     * Render servers list
     */
    render() {
        const container = document.getElementById('servers-container');

        if (this.servers.length === 0) {
            container.innerHTML = `
                <div class="bg-gray-800 p-8 rounded-lg text-center text-gray-400">
                    <p class="text-lg mb-2">No servers yet</p>
                    <p class="text-sm">Click "New Server" to create your first Minecraft server</p>
                </div>
            `;
            return;
        }

        container.innerHTML = this.servers.map(server => this.renderServerCard(server)).join('');
    }

    /**
     * Render a single server card
     */
    renderServerCard(server) {
        return `
            <div class="bg-gray-800 p-4 rounded-lg hover:bg-gray-750 transition">
                <div class="flex justify-between items-start">
                    <div class="flex-1">
                        <h3 class="text-xl font-bold">${this.escapeHtml(server.name)}</h3>
                        <div class="text-gray-400 text-sm mt-1">
                            ${server.server_type} ${server.version}
                        </div>
                        <div class="mt-2">
                            <span class="px-2 py-1 rounded text-xs ${this.getStatusColor(server.status)}">
                                ${server.status.toUpperCase()}
                            </span>
                        </div>
                        ${server.ip_address ? `
                            <div class="text-sm mt-2">
                                <span class="text-gray-400">Address:</span>
                                <span class="font-mono text-green-400">${server.ip_address}:${server.port}</span>
                            </div>
                        ` : ''}
                        <div class="text-xs text-gray-500 mt-2">
                            Created: ${new Date(server.created_at).toLocaleString()}
                        </div>
                    </div>
                    <div class="flex gap-2 flex-wrap">
                        ${server.status === 'stopped' || server.status === 'error' ? `
                            <button onclick="dashboard.startServer('${server.id}')"
                                    class="px-3 py-1 bg-green-600 hover:bg-green-700 rounded text-sm transition">
                                Start
                            </button>
                        ` : ''}
                        ${server.status === 'running' ? `
                            <button onclick="dashboard.stopServer('${server.id}')"
                                    class="px-3 py-1 bg-yellow-600 hover:bg-yellow-700 rounded text-sm transition">
                                Stop
                            </button>
                            <button onclick="dashboard.restartServer('${server.id}')"
                                    class="px-3 py-1 bg-orange-600 hover:bg-orange-700 rounded text-sm transition">
                                Restart
                            </button>
                        ` : ''}
                        <button onclick="dashboard.showConsole('${server.id}')"
                                class="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm transition">
                            Console
                        </button>
                        <button onclick="dashboard.confirmDelete('${server.id}', '${this.escapeHtml(server.name)}')"
                                class="px-3 py-1 bg-red-600 hover:bg-red-700 rounded text-sm transition">
                            Delete
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Get status badge color
     */
    getStatusColor(status) {
        const colors = {
            'running': 'bg-green-600',
            'stopped': 'bg-red-600',
            'creating': 'bg-yellow-600',
            'error': 'bg-red-800'
        };
        return colors[status] || 'bg-gray-600';
    }

    /**
     * Update statistics
     */
    updateStats() {
        const total = this.servers.length;
        const running = this.servers.filter(s => s.status === 'running').length;
        const stopped = this.servers.filter(s => s.status === 'stopped').length;
        const creating = this.servers.filter(s => s.status === 'creating').length;

        document.getElementById('stat-total').textContent = total;
        document.getElementById('stat-running').textContent = running;
        document.getElementById('stat-stopped').textContent = stopped;
        document.getElementById('stat-creating').textContent = creating;
    }

    /**
     * Show create server modal
     */
    showCreateModal() {
        document.getElementById('create-modal').classList.remove('hidden');
    }

    /**
     * Hide create server modal
     */
    hideCreateModal() {
        document.getElementById('create-modal').classList.add('hidden');
        document.getElementById('create-form').reset();
    }

    /**
     * Create a new server
     */
    async createServer(formData) {
        try {
            const isCloudDeployment = formData.provider !== 'local';

            this.showNotification('Creating server...', 'info');
            const newServer = await this.api.createServer(formData);
            this.hideCreateModal();
            await this.refresh();

            if (isCloudDeployment) {
                // Cloud deployment: Show progress modal
                this.showNotification('Server created! Starting cloud deployment...', 'success');

                setTimeout(() => {
                    this.cloudDeploy.startDeployment(newServer.id);
                }, 500);
            } else {
                // Local deployment: Show console
                this.showNotification('Server created! Opening console...', 'success');

                setTimeout(() => {
                    this.showConsole(newServer.id);
                }, 500);
            }
        } catch (error) {
            this.showNotification('Failed to create server: ' + error.message, 'error');
        }
    }

    /**
     * Confirm server deletion
     */
    confirmDelete(id, name) {
        if (confirm(`Are you sure you want to delete server "${name}"?`)) {
            this.deleteServer(id);
        }
    }

    /**
     * Delete a server
     */
    async deleteServer(id) {
        try {
            this.showNotification('Deleting server...', 'info');
            await this.api.deleteServer(id);
            await this.refresh();
            this.showNotification('Server deleted successfully!', 'success');
        } catch (error) {
            this.showNotification('Failed to delete server: ' + error.message, 'error');
        }
    }

    /**
     * Start a server
     */
    async startServer(id) {
        try {
            this.showNotification('Starting server...', 'info');
            await this.api.startServer(id);
            await this.refresh();
            this.showNotification('Server started!', 'success');
        } catch (error) {
            this.showNotification('Failed to start server: ' + error.message, 'error');
        }
    }

    /**
     * Stop a server
     */
    async stopServer(id) {
        try {
            this.showNotification('Stopping server...', 'info');
            await this.api.stopServer(id);
            await this.refresh();
            this.showNotification('Server stopped!', 'success');
        } catch (error) {
            this.showNotification('Failed to stop server: ' + error.message, 'error');
        }
    }

    /**
     * Restart a server
     */
    async restartServer(id) {
        try {
            this.showNotification('Restarting server...', 'info');
            await this.api.restartServer(id);
            await this.refresh();
            this.showNotification('Server restarted!', 'success');
        } catch (error) {
            this.showNotification('Failed to restart server: ' + error.message, 'error');
        }
    }

    /**
     * Show console modal
     */
    showConsole(serverId) {
        document.getElementById('console-modal').classList.remove('hidden');
        // Initialize console terminal
        if (window.ConsoleTerminal) {
            const terminal = new ConsoleTerminal(serverId);
            terminal.init();
        }
    }

    /**
     * Hide console modal
     */
    hideConsoleModal() {
        document.getElementById('console-modal').classList.add('hidden');
        const container = document.getElementById('terminal-container');
        container.innerHTML = '';
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Form submission
        document.getElementById('create-form').addEventListener('submit', (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            const data = Object.fromEntries(formData.entries());
            data.max_players = parseInt(data.max_players);

            // Parse server_names as array (comma-separated)
            if (data.server_names) {
                data.server_names = data.server_names.split(',').map(s => s.trim()).filter(s => s);
            }

            this.createServer(data);
        });

        // Close modal on outside click
        document.getElementById('create-modal').addEventListener('click', (e) => {
            if (e.target.id === 'create-modal') {
                this.hideCreateModal();
            }
        });

        document.getElementById('console-modal').addEventListener('click', (e) => {
            if (e.target.id === 'console-modal') {
                this.hideConsoleModal();
            }
        });

        document.getElementById('deployment-modal').addEventListener('click', (e) => {
            if (e.target.id === 'deployment-modal') {
                // Don't allow closing while deployment is in progress
                const closeBtn = document.getElementById('deployment-close-btn');
                if (!closeBtn.disabled) {
                    this.hideDeploymentModal();
                }
            }
        });
    }

    /**
     * Start polling for updates
     */
    startPolling() {
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
        }
        this.pollInterval = setInterval(() => this.refresh(), this.pollDelay);
    }

    /**
     * Stop polling
     */
    stopPolling() {
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
            this.pollInterval = null;
        }
    }

    /**
     * Show notification toast
     */
    showNotification(message, type = 'info') {
        const notification = document.getElementById('notification');
        const content = document.getElementById('notification-content');

        const colors = {
            'success': 'bg-green-600',
            'error': 'bg-red-600',
            'info': 'bg-blue-600',
            'warning': 'bg-yellow-600'
        };

        notification.className = `fixed top-4 right-4 p-4 rounded-lg shadow-lg z-50 max-w-md ${colors[type]}`;
        content.textContent = message;
        notification.classList.remove('hidden');

        setTimeout(() => {
            notification.classList.add('hidden');
        }, 3000);
    }

    /**
     * Escape HTML to prevent XSS
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Handle provider dropdown change
     */
    onProviderChange() {
        const provider = document.getElementById('provider-select').value;
        const cloudOptions = document.getElementById('cloud-options');

        if (provider === 'aws' || provider === 'azure') {
            cloudOptions.classList.remove('hidden');
        } else {
            cloudOptions.classList.add('hidden');
        }
    }

    /**
     * Hide deployment progress modal
     */
    hideDeploymentModal() {
        this.cloudDeploy.hideModal();
    }
}
