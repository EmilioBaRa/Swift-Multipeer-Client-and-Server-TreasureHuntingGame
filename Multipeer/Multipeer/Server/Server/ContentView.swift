//
//  ContentView.swift
//  Server
//
//  Created by Michael on 2022-02-24.
//

import SwiftUI

///Tile holds the X and Y value of itself. Contains it's state "hidden" and it's contents "treasure".
///Used for the contents of the board
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

///Function creates a 2D array of type Tile.
///Board is inserted with 100 tiles
///Board adds treasure to 5 random tiles
/// - Parameters: Rows is an integer that represents the number of rows in a 2D tile array
///               Columns is an integer that represents the number of columns in a 2D tile array
/// - Returns: 2D tile array
func createBoard(rows: Int, columns: Int, treasures: Int) -> [[Tile]]{
    var board = [[Tile]]();
    
    for i in 0..<columns{
        board.insert([Tile](), at: i);
        for j in 0..<rows{
            let newTile = Tile(hidden: true, treasure: false, xLocation: i, yLocation: j);
            board[i].insert(newTile, at: j);
        }
    }
    
    var addedTreasure = 0;
    while(addedTreasure < treasures){
        
        let x = Int(arc4random()%10);
        let y = Int(arc4random()%10);
        
        if(!board[x][y].treasure){
            board[x][y].treasure = true;
            addedTreasure += 1;
        }
    }
    
    return board;
}
///Server waits for atleast 2 concurrent connections.
///The server then displays the board using HStacks for 
///each row. Dependent on the tiles status "hidden, treasure" the server will display a different image as the tile
///Server sends the 2D board array to the concurrent connections.
struct ContentView: View {
    @State var advertising = false;
    @StateObject var networkSupport = NetworkSupport(browse: false);
    
    var body: some View {
        VStack {
            if !advertising {
                Button("Start") {
                    networkSupport.nearbyServiceAdvertiser?.startAdvertisingPeer()
                    advertising.toggle()
                }
            }
            else {
                if(networkSupport.peers.count == 2){
                    ForEach(networkSupport.board, id: \.self) { row in
                        HStack {
                            ForEach(row, id: \.self) { tile in
                                
                                if(tile.hidden) {
                                    Image(systemName: "capsule.fill")
                                } else {
                                    if(tile.treasure) {
                                        Image(systemName: "circle.dashed.inset.filled")
                                    } else {
                                        Image(systemName: "capsule")
                                    }
                                    
                                }
                            }
                        }
                    }
                
                    if networkSupport.connected {
                        Button("Reply") {
                            networkSupport.send(board: networkSupport.board)
                            print("Connections: " + String(networkSupport.peers.count));
                        }
                        .padding()
                    }
                }
                Button("Stop") {
                    networkSupport.nearbyServiceAdvertiser?.stopAdvertisingPeer()
                    advertising.toggle()
                }
                .padding()
            }
        }
        .padding()
    }
}
