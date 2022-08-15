//
//  NetworkSupport.swift
//  Server
//
//  Created by Michael on 2022-02-24.
//

import Foundation
import MultipeerConnectivity
import os

/// Uniquely identifies the service.
/// Make this unique to avoid interfering with other Multipeer services.
/// Don't forget to update the project Info AND the project Info.plist property lists accordingly.
let serviceType = "l10-031-043-042"

/// This structure is used at setup time to identify client needs to a server.
/// Currently, it only contains an identifying message, but this can be expanded to contain version information and other data.
struct Request: Codable {
    /// An identifying message that is to be transmitted.
    var details: String
}

/// This class deals with matters relating to setting up Server and Client Multipeer services.
class NetworkSupport: NSObject, ObservableObject, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    /// The local peer identifier
    private var peerID: MCPeerID
    
    /// The current session
    private var session: MCSession
    
    /// For a server, this allows access to the MCNearbyServiceAdvertiser; nil otherwise.
    var nearbyServiceAdvertiser: MCNearbyServiceAdvertiser?
    
    /// For a client, this allows access to the MCNearbyServiceBrowser; nil otherwise.
    var nearbyServiceBrowser: MCNearbyServiceBrowser?
    
    /// Contains the list of connected peers.  Used by the client.
    @Published var peers: [MCPeerID] = [MCPeerID]()
    
    /// True if connected to a peer, false otherwise.
    @Published var connected = false
    
    /// Contains the most recent incoming board coordinates
    @Published var incomingCoordinates = ["" : ""];
    
    /// Contains the game board (createBoard function is located in ContentView file)
    @Published var board : [[Tile]] = createBoard(rows: 10, columns: 10, treasures: 5);
    
    /// Contains the score for player one
    @Published var playerOneScore : Int = 0
    
    /// Contains the score for player two
    @Published var playerTwoScore : Int = 0
    
    /// Is true if all the treasure has been found
    @Published var isFinished : Bool = false
    
    /// The index which represent the player turn inside the array peers[]. In this case it starts from zero since
    /// the first player who can make a change in the board is the index 0.
    var actualPlayerIndex = 0;
    
    /// Create a Multipeer Server or Client
    /// - Parameter browse: true creates a Client, false creates a Server
    init(browse: Bool) {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        if !browse {
            nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        }
        else {
            nearbyServiceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        }
        
        super.init()
        
        session.delegate = self
        nearbyServiceAdvertiser?.delegate = self
        nearbyServiceBrowser?.delegate = self
        
        if browse {
            nearbyServiceBrowser?.startBrowsingForPeers()
        }
    }
    
    // MARK: - MCNearbyServiceAdvertiserDelegate Methods. See XCode documentation for details.
    
    /// Inherited from MCNearbyServiceAdvertiserDelegate.advertiser(_:didNotStartAdvertisingPeer:).
    /// Currently only logs.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        os_log("didNotStartAdvertisingPeer \(error.localizedDescription)")
    }
    
    /// Inherited from MCNearbyServiceAdvertiserDelegate.advertiser(_:didReceiveInvitationFromPeer:withContext:invitationHandler:).
    /// Right now, all connection requests are accepted.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        do {
            let request = try JSONDecoder().decode(Request.self, from: context ?? Data())
            os_log("didReceiveInvitationFromPeer \(peerID.displayName) \(request.details)")
            
            invitationHandler(true, self.session)
        }
        catch let error {
            os_log("didReceiveInvitationFromPeer \(error.localizedDescription)")
        }
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate Methods. See XCode documentation for details.
    
    /// Adds the given peer to the peers array.
    /// - Parameter peer: The peer to be added.
    private func addPeer(peer: MCPeerID) {
        DispatchQueue.main.async {
            if !self.peers.contains(peer) {
                os_log("addPeer")
                self.peers.append(peer)
            }
        }
    }
    
    /// Removes the given peer from the peers array, if possible.
    /// - Parameter peer: The peer to be removed.
    private func removePeer(peer: MCPeerID) {
        DispatchQueue.main.async {
            guard let index = self.peers.firstIndex(of: peer) else {
                return
            }
            os_log("removePeer")
            self.peers.remove(at: index)
        }
    }
    
    /// Inherited from MCNearbyServiceBrowserDelegate.browser(_:didNotStartBrowsingForPeers:).
    /// Currently only logs.
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        os_log("didNotStartBrowsingForPeers \(error.localizedDescription)")
    }
    
    /// Inherited from MCNearbyServiceBrowserDelegate.browser(_:foundPeer:withDiscoveryInfo:).
    /// Updates the peers array with the newly-found peerID.
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let info2 = info?.description ?? ""
        os_log("foundPeer \(peerID) \(info2)")
        addPeer(peer: peerID)
    }
    
    /// Inherited from MCNearbyServiceBrowserDelegate.browser(_:lostPeer:).
    /// Removes the lost peerID from the peers array and updates connected status.
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        os_log("lostPeer \(peerID)")
        removePeer(peer: peerID)
        DispatchQueue.main.async {
            self.connected = false
        }
    }
    
    // MARK: - Client Setup Method
    
    /// Establish a session with a server.
    /// - Parameters:
    ///   - peerID: The peer ID of the server.
    ///   - request: The connection request.  This can contain additional information that can be used by a server to accept or reject a connection.
    func contactPeer(peerID: MCPeerID, request: Request) throws {
        os_log("contactPeer \(peerID) \(request.details)")
        let request = try JSONEncoder().encode(request)
        nearbyServiceBrowser?.invitePeer(peerID, to: session, withContext: request, timeout: TimeInterval(120))
    }
    
    // MARK: - MCSessionDelegate Methods. See XCode documentation for details.
    
    /// Inherited from MCSessionDelegate.session(_:didReceive:fromPeer:).
    /// Updates incomingMessage with the message that was just received
    /// The message is expected to be a dictionary in format [String : String]
    func session(_ session: MCSession, didReceive: Data, fromPeer: MCPeerID) {
        do {
            let request = try JSONDecoder().decode([String : String].self, from: didReceive)
            os_log("didReceive \(request) \(fromPeer)")
            DispatchQueue.main.async {
                self.incomingCoordinates = request;
                self.playerTurn(fromPeer: fromPeer);
            }
        }
        catch let error {
            os_log("didReceive \(error.localizedDescription)")
        }
    }
    
    // GAME LOGIC METHODS
    /// Function checks the turn of the player
    /// If the received message is from the current players turn and the game hasn't finished the state of the tile is changed to not hidden
    /// The player turn changes
    /// - Parameters: fromPeer is the peer id of the player that send the message to the server
    func playerTurn(fromPeer: MCPeerID){
        if(fromPeer == self.peers[self.actualPlayerIndex] && !isFinished){
            self.changeTileState(coordinates: self.incomingCoordinates, board: self.board);
            self.send(board: self.board);
            //next player turn
            self.actualPlayerIndex = self.actualPlayerIndex == 0 ? 1 : 0;
        }
    }
    /// Function changes the state of the tile
    /// It takes the coordinates from the parameters and once the tile is found it changes its state
    /// - Parameters: coordinates is a dictionary of strings representing  the coordinates of the desired tile to change
    ///               board is the board that we are currently working with and where the tile is located
    func changeTileState(coordinates: [String : String], board: [[Tile]]){
        changeTile(x: coordinates["x"]!, y: coordinates["y"]!, board: board)
    }
    /// Function is going to get the tile which has the x and y  coordinates in xLocation and yLocation
    /// Then, the tile hidden state is going to be changed to false
    /// and if the tile is a trreasure the score will increment for the player that found the treasure
    /// - Parameters: x is the representation of a column from the board
    ///               y is the representation of a row from the board
    ///               board is the board that we are currently working with and where the tile is located
    func changeTile(x: String, y: String, board: [[Tile]]) -> Void{
        for i in 0..<Int(y)!{
            let tile = board[i].firstIndex { String($0.xLocation) == x && String($0.yLocation) == y};
            if((tile) != nil){
                self.board[i][tile!].hidden = false;
                if(self.board[i][tile!].treasure){
                    if(actualPlayerIndex == 0){
                        self.playerOneScore += 1
                    }else if(actualPlayerIndex == 1){
                        self.playerTwoScore += 1
                    }
                    sendScore()
                }
            }
        }
    }
    
    
    /// Inherited from MCSessionDelegate.session(_:didStartReceivingResourceWithName:fromPeer:with:).
    /// Currently only logs.
    func session(_ session: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {
        os_log("didStartReceivingResourceWithName \(didStartReceivingResourceWithName) \(fromPeer) \(with)")
    }
    
    /// Inherited from MCSessionDelegate.session(_:didFinishReceivingResourceWithName:fromPeer:at:withError:).
    /// Currently only logs.
    func session(_ session: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {
        let at2 = at?.description ?? ""
        let withError2 = withError?.localizedDescription ?? ""
        os_log("didFinishReceivingResourceWithName \(didFinishReceivingResourceWithName) \(fromPeer) \(at2) \(withError2)")
    }
    
    /// Inherited from MCSessionDelegate.session(_:didReceive:withName:fromPeer:).
    /// Currently only logs.
    func session(_ session: MCSession, didReceive: InputStream, withName: String, fromPeer: MCPeerID) {
        os_log("didReceive:withName \(didReceive) \(withName) \(fromPeer)")
    }
    
    /// Inherited from MCSessionDelegate.session(_:peer:didChange:).
    /// Updates the connected state.
    func session(_ session: MCSession, peer: MCPeerID, didChange: MCSessionState) {
        switch didChange {
        case .notConnected:
            os_log("didChange notConnected \(peer)")
            removePeer(peer: peer)
            DispatchQueue.main.async {
                self.connected = false
            }
        case .connecting:
            os_log("didChange connecting \(peer)")
            DispatchQueue.main.async {
                self.connected = false
            }
        case .connected:
            os_log("didChange connected \(peer)")
            addPeer(peer: peer)
            DispatchQueue.main.async {
                self.connected = true
            }
        default:
            os_log("didChange \(peer)")
            DispatchQueue.main.async {
                self.connected = false
            }
        }
    }
    
    /// Inherited from MCSessionDelegate.session(_:didReceiveCertificate:fromPeer:certificateHandler:).
    /// Currently accepts all certificates.
    func session(_ session: MCSession, didReceiveCertificate: [Any]?, fromPeer: MCPeerID, certificateHandler: (Bool) -> Void) {
        let didReceiveCertificate2 = didReceiveCertificate?.description ?? ""
        os_log("didReceiveCertificate \(didReceiveCertificate2) \(fromPeer)")
        certificateHandler(true)
    }
    
    // MARK: - Data Transmission Method
    
    /// Sends the board to all registered peers.  Used by the client.
    /// - Parameter board: The board that is to be transmitted to the players.
    func send(board: [[Tile]]) {
        do {
            let data = try JSONEncoder().encode(board)
            try session.send(data, toPeers: peers, with: .reliable)
            //os_log("send \wouldbeboard"<#StaticString#>)
        }
        catch let error {
            os_log("send \(error.localizedDescription)")
        }
    }
    /// sendScore will check if the game has finished (all treasures have been found) and will call sendScoreStatePeers with a unique message
    /// depending on the peer, and the state of the game.
    /// - Returns : No return values
    func sendScore(){
        if(playerTwoScore + playerOneScore > 4){
            isFinished = true
        }
        if(!isFinished){
            sendScoreStatePeers(message: "Your Score: \(playerOneScore) - Opponent Score: \(playerTwoScore)", playerIndex: 0)
            sendScoreStatePeers(message: "Your Score: \(playerTwoScore) - Opponent Score: \(playerOneScore)", playerIndex: 1)
        }else{
            if(playerOneScore > playerTwoScore){
                sendScoreStatePeers(message: "You Win! \(playerOneScore) - \(playerTwoScore)", playerIndex: 0)
                sendScoreStatePeers(message: "Your Lose! \(playerTwoScore) - \(playerOneScore)", playerIndex: 1)
            }else{
                sendScoreStatePeers(message: "You Lose! \(playerOneScore) - \(playerTwoScore)", playerIndex: 0)
                sendScoreStatePeers(message: "Your Win! \(playerTwoScore) - \(playerOneScore)", playerIndex: 1)
            }
        }
    }
    ///Will send the score state to a specific peer dependenant on the playerIndex
    /// - Parameter message: a Message that will be sent to the player
    ///             playerIndex: the index of the player to be used on peers array
    /// - Returns: No return values
    func sendScoreStatePeers(message: String, playerIndex: Int){
        do{
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peers[playerIndex]], with: .reliable)
        }catch let error {
            os_log("send \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        os_log("deinit")
        nearbyServiceBrowser?.stopBrowsingForPeers()
    }
}
