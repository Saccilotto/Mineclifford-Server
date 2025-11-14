/**
 * Cloud Deployment Manager
 * Handles WebSocket connection for real-time cloud deployment progress
 */
class CloudDeploymentManager {
    constructor() {
        this.ws = null;
        this.serverId = null;
        this.logs = [];
    }

    /**
     * Start cloud deployment with WebSocket progress tracking
     */
    async startDeployment(serverId) {
        this.serverId = serverId;
        this.logs = [];

        // Show deployment modal
        this.showModal();

        // Determine WebSocket protocol (ws or wss)
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.host;
        const wsUrl = `${protocol}//${host}/api/servers/deploy-cloud/${serverId}`;

        console.log('Connecting to WebSocket:', wsUrl);

        try {
            this.ws = new WebSocket(wsUrl);

            this.ws.onopen = () => {
                console.log('WebSocket connected');
                this.updateStatus('Connected', 'text-blue-400');
                this.addLog('[INFO] WebSocket connection established');
            };

            this.ws.onmessage = (event) => {
                const update = JSON.parse(event.data);
                console.log('Deployment update:', update);
                this.handleUpdate(update);
            };

            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
                this.updateStatus('Connection Error', 'text-red-400');
                this.addLog('[ERROR] WebSocket connection failed');
            };

            this.ws.onclose = () => {
                console.log('WebSocket closed');
                this.enableCloseButton();
            };

        } catch (error) {
            console.error('Failed to start deployment:', error);
            this.updateStatus('Failed to Start', 'text-red-400');
            this.addLog(`[ERROR] ${error.message}`);
            this.enableCloseButton();
        }
    }

    /**
     * Handle deployment update from WebSocket
     */
    handleUpdate(update) {
        // Update status
        if (update.message) {
            this.updateStatus(update.message, this.getStatusColor(update.status));
            this.addLog(`[${update.stage?.toUpperCase() || 'INFO'}] ${update.message}`);
        }

        // Update stage indicators
        if (update.stage) {
            if (update.stage === 'terraform') {
                this.updateStage('terraform', update.status);
            } else if (update.stage === 'ansible') {
                this.updateStage('ansible', update.status);
            } else if (update.stage === 'complete') {
                this.updateStage('terraform', 'success');
                this.updateStage('ansible', 'success');
                this.showResult(update);
            } else if (update.stage === 'error') {
                if (this.logs.some(log => log.includes('terraform'))) {
                    this.updateStage('terraform', 'error');
                }
                if (this.logs.some(log => log.includes('ansible'))) {
                    this.updateStage('ansible', 'error');
                }
            }
        }

        // Show final result
        if (update.status === 'complete' || update.status === 'success') {
            this.showResult(update);
        }
    }

    /**
     * Update deployment status text
     */
    updateStatus(message, colorClass = 'text-yellow-400') {
        const statusEl = document.getElementById('deployment-status');
        if (statusEl) {
            statusEl.textContent = message;
            statusEl.className = `text-lg font-semibold ${colorClass}`;
        }
    }

    /**
     * Update stage indicator
     */
    updateStage(stage, status) {
        const stageEl = document.getElementById(`stage-${stage}`);
        if (!stageEl) return;

        const icon = stageEl.querySelector('.stage-icon');
        const statusText = stageEl.querySelector('.text-xs');

        // Update icon
        if (status === 'initializing' || status === 'planning' || status === 'applying' || status === 'preparing' || status === 'running') {
            icon.innerHTML = '<div class="w-4 h-4 border-2 border-yellow-400 border-t-transparent rounded-full animate-spin"></div>';
            icon.className = 'stage-icon w-6 h-6 rounded-full bg-yellow-900 flex items-center justify-center';
            statusText.textContent = 'In Progress...';
            statusText.className = 'text-xs text-yellow-400 mt-1 ml-8';
        } else if (status === 'success') {
            icon.innerHTML = '✓';
            icon.className = 'stage-icon w-6 h-6 rounded-full bg-green-600 flex items-center justify-center text-white';
            statusText.textContent = 'Completed';
            statusText.className = 'text-xs text-green-400 mt-1 ml-8';
        } else if (status === 'error') {
            icon.innerHTML = '✗';
            icon.className = 'stage-icon w-6 h-6 rounded-full bg-red-600 flex items-center justify-center text-white';
            statusText.textContent = 'Failed';
            statusText.className = 'text-xs text-red-400 mt-1 ml-8';
        }
    }

    /**
     * Add log entry
     */
    addLog(message) {
        this.logs.push(message);

        const logsEl = document.getElementById('deployment-logs');
        if (logsEl) {
            // Append new log line
            logsEl.textContent = this.logs.join('\n');

            // Auto-scroll to bottom
            logsEl.scrollTop = logsEl.scrollHeight;
        }
    }

    /**
     * Show final deployment result
     */
    showResult(update) {
        const resultEl = document.getElementById('deployment-result');
        const ipEl = document.getElementById('deployment-ip');

        if (resultEl && ipEl && update.server_ip) {
            ipEl.textContent = `${update.server_ip}:${update.port || 25565}`;
            resultEl.classList.remove('hidden');
        }

        this.enableCloseButton();
    }

    /**
     * Get color class based on status
     */
    getStatusColor(status) {
        const colors = {
            'started': 'text-blue-400',
            'initializing': 'text-yellow-400',
            'planning': 'text-yellow-400',
            'applying': 'text-yellow-400',
            'preparing': 'text-yellow-400',
            'running': 'text-yellow-400',
            'success': 'text-green-400',
            'complete': 'text-green-400',
            'error': 'text-red-400',
            'failed': 'text-red-400'
        };

        return colors[status] || 'text-gray-400';
    }

    /**
     * Show deployment modal
     */
    showModal() {
        const modal = document.getElementById('deployment-modal');
        if (modal) {
            modal.classList.remove('hidden');

            // Reset modal state
            this.updateStatus('Initializing...', 'text-yellow-400');
            document.getElementById('deployment-logs').textContent = 'Connecting to deployment service...';
            document.getElementById('deployment-result').classList.add('hidden');
            document.getElementById('deployment-close-btn').disabled = true;

            // Reset stages
            this.resetStage('terraform');
            this.resetStage('ansible');
        }
    }

    /**
     * Hide deployment modal
     */
    hideModal() {
        const modal = document.getElementById('deployment-modal');
        if (modal) {
            modal.classList.add('hidden');
        }

        // Close WebSocket if still open
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }

    /**
     * Reset stage indicator
     */
    resetStage(stage) {
        const stageEl = document.getElementById(`stage-${stage}`);
        if (!stageEl) return;

        const icon = stageEl.querySelector('.stage-icon');
        const statusText = stageEl.querySelector('.text-xs');

        icon.innerHTML = '<div class="w-2 h-2 rounded-full bg-gray-600"></div>';
        icon.className = 'stage-icon w-6 h-6 rounded-full border-2 border-gray-600 flex items-center justify-center';
        statusText.textContent = 'Pending';
        statusText.className = 'text-xs text-gray-400 mt-1 ml-8';
    }

    /**
     * Enable close button
     */
    enableCloseButton() {
        const closeBtn = document.getElementById('deployment-close-btn');
        if (closeBtn) {
            closeBtn.disabled = false;
        }
    }
}
