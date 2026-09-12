// Native JavaScript WebRTC handler for web platform
// This bypasses flutter_webrtc's broken callback system on web

class WebRTCHandler {
  constructor() {
    this.peerConnection = null;
    this.localStream = null;
    this.remoteStream = null;
    this.onIceCandidateCallback = null;
    this.onTrackCallback = null;
    this.onConnectionStateChangeCallback = null;
  }

  async createPeerConnection(iceServers) {
    console.log('[JS WebRTC] Creating peer connection with STUN servers');

    this.peerConnection = new RTCPeerConnection({
      iceServers: iceServers || [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ]
    });

    // Set up event listeners
    this.peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        console.log('[JS WebRTC] 🧊 ICE candidate generated!', event.candidate);
        if (this.onIceCandidateCallback) {
          this.onIceCandidateCallback({
            candidate: event.candidate.candidate,
            sdpMid: event.candidate.sdpMid,
            sdpMLineIndex: event.candidate.sdpMLineIndex
          });
        }
      }
    };

    this.peerConnection.ontrack = (event) => {
      console.log('[JS WebRTC] ⭐ Track received!', event.track.kind);
      if (event.streams && event.streams[0]) {
        this.remoteStream = event.streams[0];
        if (this.onTrackCallback) {
          this.onTrackCallback(this.remoteStream);
        }
      }
    };

    this.peerConnection.onconnectionstatechange = () => {
      console.log('[JS WebRTC] Connection state:', this.peerConnection.connectionState);
      if (this.onConnectionStateChangeCallback) {
        this.onConnectionStateChangeCallback(this.peerConnection.connectionState);
      }
    };

    this.peerConnection.oniceconnectionstatechange = () => {
      console.log('[JS WebRTC] ICE connection state:', this.peerConnection.iceConnectionState);
    };

    this.peerConnection.onicegatheringstatechange = () => {
      console.log('[JS WebRTC] ICE gathering state:', this.peerConnection.iceGatheringState);
    };

    return true;
  }

  async createOffer() {
    console.log('[JS WebRTC] Creating offer...');

    // Add transceivers BEFORE creating offer - this triggers ICE gathering
    // even without a real camera (required for ICE candidates to generate)
    try {
      this.peerConnection.addTransceiver('video', { direction: 'recvonly' });
      this.peerConnection.addTransceiver('audio', { direction: 'recvonly' });
      console.log('[JS WebRTC] ✅ Transceivers added (video+audio recvonly)');
    } catch (e) {
      console.warn('[JS WebRTC] Could not add transceivers:', e);
    }

    const offer = await this.peerConnection.createOffer();
    await this.peerConnection.setLocalDescription(offer);
    console.log('[JS WebRTC] Local description set (offer)');
    return {
      type: offer.type,
      sdp: offer.sdp
    };
  }

  async createAnswer() {
    console.log('[JS WebRTC] Creating answer...');
    const answer = await this.peerConnection.createAnswer();
    await this.peerConnection.setLocalDescription(answer);
    console.log('[JS WebRTC] Local description set (answer)');
    return {
      type: answer.type,
      sdp: answer.sdp
    };
  }

  async setRemoteDescription(description) {
    console.log('[JS WebRTC] Setting remote description:', description.type);
    await this.peerConnection.setRemoteDescription(
      new RTCSessionDescription(description)
    );
    console.log('[JS WebRTC] Remote description set');
  }

  async addIceCandidate(candidate) {
    console.log('[JS WebRTC] Adding ICE candidate');
    await this.peerConnection.addIceCandidate(
      new RTCIceCandidate(candidate)
    );
  }

  async getUserMedia(constraints) {
    console.log('[JS WebRTC] Getting user media...');
    this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
    console.log('[JS WebRTC] Got user media - tracks:',
      this.localStream.getTracks().map(t => t.kind));
    return this.localStream;
  }

  addTrack(track) {
    if (this.localStream) {
      this.peerConnection.addTrack(track, this.localStream);
      console.log('[JS WebRTC] Added track:', track.kind);
    }
  }

  getConnectionState() {
    return this.peerConnection?.connectionState || 'new';
  }

  close() {
    console.log('[JS WebRTC] Closing peer connection');
    this.peerConnection?.close();
    this.localStream?.getTracks().forEach(track => track.stop());
    this.peerConnection = null;
    this.localStream = null;
    this.remoteStream = null;
  }
}

// Global instance
window.webrtcHandler = new WebRTCHandler();

console.log('[JS WebRTC] Handler initialized and ready');
