//
//  ContentView.swift
//  Client
//
//  Created by Michael on 2022-02-24.
//

import SwiftUI

//Tile holds the X and Y value of itself. Contains it's state "hidden" and it's contents "treasure".
//Used for the contents of the board
struct Tile : Encodable, Decodable ,Hashable{
    //State of tile
    var hidden : Bool;
    //If the tile contains treasure
    var treasure : Bool;
    //X location of the tile in a 2D array
    var xLocation : Int;
    //Y location of the tile in a 2D array
    var yLocation : Int;
}


///ContentView waits for an available server to connect to, then provides an option
///to connect to said server.
///After connecting to the server, contentView will then wait for the board
///to be sent by the server. Once the board is sent by the server,
///contentView will display the 10x10 board of Tiles by creating a HStack for each row
///Each tile displayed has a tapGesture that sends it's coordinates back to the server
struct ContentView: View {
    //Message written on text field
    @State var message = ""
    //the network that the client is going to connect
    @StateObject var networkSupport = NetworkSupport(browse: true)
    //Message that is going to be sent to the server
    @State var outgoingMessage = ""
    var body: some View {
        VStack {
            if !networkSupport.connected {
                TextField("Message", text: $message)
                    .multilineTextAlignment(.center)
                
                List ($networkSupport.peers, id: \.self) {
                    $peer in
                    Button(peer.displayName) {
                        do {
                            try networkSupport.contactPeer(peerID: peer, request: Request(details: message))
                        }
                        catch let error {
                            print(error)
                        }
                    }
                }
            }
            else {
                ///Score of current game
                VStack {
                    Text(networkSupport.ScoreLabel)
                }
                //If the game is not yet completed
                if(!networkSupport.finishedGame){
                    //For each row
                    ForEach(networkSupport.incomingBoard, id: \.self) { row in
                        HStack {
                            ForEach(row, id: \.self) {
                                tile in
                                //If tile is hidden (yet to be tapped) 
                                if(tile.hidden) {
                                    Image(systemName: "capsule.fill")
                                        .onTapGesture {
                                            networkSupport.send(coordinates: ["x": String(tile.xLocation), "y": String(tile.yLocation)]);
                                        }
                                }
                                //If tile is not hidden and contains treasure
                                //Else tile is not hidden and doesn't contain treasure
                                else {
                                    if(tile.treasure) {
                                        Image(systemName: "circle.dashed.inset.filled")
                                    } else {
                                        Image(systemName: "capsule")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
