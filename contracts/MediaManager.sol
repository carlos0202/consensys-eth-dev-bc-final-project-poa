pragma solidity ^0.5.0;


import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./external/EternalStorage.sol";


/** @title Media Manager contract using Proof of Existence to validate ownership.
  * This contract uses zeppelin's Ownable and Pausable imports to manage owner capabilities
  * and pause the sensitive functionalities of the contract when necessary.
  *
  * The information stored using this contract is put into a EternalStorage variable
  * to allow upgradeability of the contract while preserving state data following
  * zeppelinos guidelines about EternalStorage.
  */
contract MediaManager is Ownable, Pausable{
    // Type declarations of the contract
    using SafeMath for uint;
    
    // State variables of the contract
    EternalStorage public db;

    // Events of the contract
    event MediaAdded(string indexed mediaHash, uint indexed mediaIndex, address indexed mediaOwner);
    event MediaDeleted(string indexed mediaHash, uint indexed mediaIndex, address indexed mediaOwner);
    event ContractTransfered(address indexed oldAddress, address indexed newAddress);

    // Contract's constructor
    constructor() public {
        Ownable(msg.sender);
        db = new EternalStorage();
        // initialize mapping indexes to use while saving or retrieving proof data
        // from EternalStorage.
        // Store index of last added media. (set at 0 because no media exists when first instantiated)
        db.setUint(getHashIndex("lastMediaIndex"), 0);
    }

    /** @dev Fallback to reject any ether sent to contract
    */
    function () public { }

    // External functions

    // External functions that are view

    // External functions that are pure

    // Public functions
    /** @dev Give the contract proxy to a new contract by allowing it to manipulate storage
    * @param newAddress the address of new contract proxy deployed.
    * @return success If the transaction is processed successfully
    */
    function upgradeContract(address newAddress) public onlyOwner returns (bool success) {
        require(newAddress != address(0));
        // Transfer ownership of the state data to the new address
        db.transferOwnership(newAddress);
        // Emit the corresponding event
        emit ContractTransfered(this, newAddress);

        return true;
    }

    // Internal functions
    /** @dev Computes the hash to use as index to store a value in the .
    * @param mappingName the name to use if we want to have some structured
    * information pattern like struct while saving data in the EternalStorage.
    * @param index the index to use for the structured data collection index
    * in the storage.
    * @param varName a name to have as reference for the variable inside the
    * mapping like a property of a struct in terms of reference.
    * @return the hash to use as index for the corresponding mapping inside
    * the EternalStorage.
    */
    function getHashIndex(string mappingName, uint index, string varName) 
        internal 
        pure 
        returns (string nHash) 
    {
        nHash = keccak256(abi.encodePacked(mappingName, index, varName));
    }

    /** @dev Computes the hash to use as index to store a value in the .
    * @param mappingName the name to use if we want to have some structured
    * information pattern like struct while saving data in the EternalStorage.
    * @param varName a name to have as reference for the variable inside the
    * mapping like a property of a struct in terms of reference.
    * @return the hash to use as index for the corresponding mapping inside
    * the EternalStorage.
    */
    function getHashIndex(string mappingName, string varName) 
        internal 
        pure 
        returns (string nHash) 
    {
        nHash = keccak256(abi.encodePacked(mappingName, varName));
    }

    /** @dev Computes the hash to use as index to store a value in the .
    * @param mappingName the name to use if we want to have some structured
    * information pattern like struct while saving data in the EternalStorage.
    * @return the hash to use as index for the corresponding mapping inside
    * the EternalStorage.
    */
    function getHashIndex(string mappingName) 
        internal 
        pure 
        returns (string nHash) 
    {
        nHash = keccak256(abi.encodePacked(mappingName));
    }

    /** @dev Computes the hash to use as index to store a value in the .
    * @param mappingName the name to use if we want to have some structured
    * information pattern like struct while saving data in the EternalStorage.
    * @return the hash to use as index for the corresponding mapping inside
    * the EternalStorage.
    */
    function getMediaOwner(uint mediaIndex) 
        internal 
        view 
        returns (address mediaOwner) 
    {
        // Get the owner address of the media
        mediaOWner = db.getAddress(getHashIndex('mediaMap', mediaIndex, 'mediaOwner'));
    }
    
    /** @dev Registers an IPFS file hash and its extra data to  the contract's storage.
    * @param mediaHash the IPFS file hash to register.
    * @param isVideo determines if the hash stored corresponds to a video uploaded to IPFS.
    * @param title a title to give to the upload media for screening purposes.
    * @param description a short description to give about the uploaded media.
    * @return the publicHash that would be used as a proof of the existence of the media file
    * in the blockchain if the transaction ocurred without errors.
    */
    function addOwnedMedia(
        string mediaHash, 
        bool isVideo, 
        string title, 
        string description
    ) 
        public 
        whenNotPaused() 
        returns (string publicHash) 
    {
        // The same media cannot be added twice
        require(db.getUint(getHashIndex('mediaHashMap', mediaHash)) == 0);
        // Get saved media index count starting at 0 and add 1 to insert first at 1;
        uint mediaIndex = db.getUint(getHashIndex("lastMediaIndex")).add(1);
        // Get saved media index for current caller of the method.
        uint userMediaIndex = db.getUint(getHashIndex('userMediaMap', msg.sender, 'userMediaIndex'));
        // Get the public hash that will be used as a reference for the stored
        // media file instead of using the IPFS hash directly.
        publicHash = getHashIndex('mediaHashMap', mediaHash);

        // Save main information aboud the media file to add
        // Save wether the uploaded media is a video property.
        db.setBool(getHashIndex('mediaMap', mediaIndex, 'isVideo'), isVideo);
        // Save the associated title to the media.
        db.setString(getHashIndex('mediaMap', mediaIndex, 'title'), title);
        // Save the description associated to the media.
        db.setString(getHashIndex('mediaMap', mediaIndex, 'description'), description);
        // Save the timestamp of this transaction in the mapping
        db.setUint(getHashIndex('mediaMap', mediaIndex, 'timestamp'), now);
        // Save the media hash obtained fro IPFS
        db.setString(getHashIndex('mediaMap', mediaIndex, 'mediaHash'), mediaHash);
        // Save the owner address of the media
        db.setAddress(getHashIndex('mediaMap', mediaIndex, 'mediaOwner'), msg.sender);

        // Save information regarding the map of users and its media files.
        // Store the reference of the current media file associated with a 
        // key created using the users address and the current index in the map.
        db.setUint(getHashIndex('userMediaMap', msg.sender, userMediaIndex), mediaIndex);
        // Store the index for the next media file to add in the map array.
        db.setUint(getHashIndex('userMediaMap', msg.sender, 'userMediaIndex'), userMediaIndex.add(1));

        // Save index information of the media hash and its current position in the maps.
        // Save current media index with the hash as its key
        db.setUint(publicHash, mediaIndex);
        // Update info regarding the last inserterd media index
        db.setUint(getHashIndex('lastMediaIndex'), mediaIndex);

        // emit corresponding event
        emit MediaAdded(mediaHash, mediaIndex, msg.sender);

        return publicHash;
    }

    /** @dev Deletes an IPFS file hash and its extra data of the contract's storage.
    * @param publicHash the IPFS file hash to delete.
    * @return boolean value indicating that the delete operation was successsful.
    */
    function deleteOwnedMedia(string publicHash) 
        public 
        whenNotPaused() 
        returns (bool mediaDeleted) 
    {
        // Get saved media index of the media file.
        uint mediaIndex = db.getUint(publicHash);
        // The media file must exists in the storage.
        require(mediaIndex != 0, 'The media file to delete must exist!');
        // The owner of the media file must be the one calling this method
        require(
            getMediaOwner(mediaIndex) == msg.sender,
            'Only the owner of the media file can delete it!'
        );

        // Get saved media index for current caller of the method.
        uint userMediaIndex = db.getUint(getHashIndex('userMediaMap', msg.sender, 'userMediaIndex'));
        // Get the public hash that will be used as a reference for the stored
        // media file instead of using the IPFS hash directly.
        publicHash = getHashIndex('mediaHashMap', mediaHash);

        // Delete main information aboud the media file
        // Delete is a video property.
        db.deleteBool(getHashIndex('mediaMap', mediaIndex, 'isVideo'));
        // Delete the associated title to the media.
        db.deleteString(getHashIndex('mediaMap', mediaIndex, 'title'));
        // Delete the description associated to the media.
        db.deleteString(getHashIndex('mediaMap', mediaIndex, 'description'));
        // Delete the timestamp of this transaction in the mapping
        db.deleteUint(getHashIndex('mediaMap', mediaIndex, 'timestamp'));
        // Delete the media hash obtained fro IPFS
        db.deleteString(getHashIndex('mediaMap', mediaIndex, 'mediaHash'));
        // Delete the owner address of the media
        db.deleteAddress(getHashIndex('mediaMap', mediaIndex, 'mediaOwner'));

        // delete information regarding the map of users and its media files.
        // delete the reference of the current media file associated with a 
        // key created using the users address and the current index in the map.
        db.deleteUint(getHashIndex('userMediaMap', msg.sender, userMediaIndex));
        // Delete current media index with the hash as its key
        db.deleteUint(publicHash);

        // emit corresponding event
        emit MediaDeleted(mediaHash, mediaIndex, msg.sender);
        mediaDeleted = true;

        return mediaDeleted;
    }    

    /** @dev Returns all the information stored about the media file in the corresponding
    * index sent as parameter.
    * @param mediaIndex - index of registered media file in the storage.
    * @return the media file is a video (isVideo).
    * @return associated title of the media file (title).
    * @return associated description of the media file (description).
    * @return the timestamp when media file was saved in the blockchain.
    * @return the media file hash obtained fro IPFS.
    * @return the address of the owner of this media file.
    */
    function getMedia(uint mediaIndex) public view returns (
        bool isVideo,
        string title,
        string description,
        uint timestamp,
        string mediaHash,
        address mediaOwner
    ) {
        require(mediaIndex > 0);
        // Get information aboud the media file added
        // Get is a video property.
        isVideo = db.getBool(getHashIndex('mediaMap', mediaIndex, 'isVideo'));
        // Get the associated title to the media.
        title = db.getString(getHashIndex('mediaMap', mediaIndex, 'title'));
        // Get the description associated to the media.
        description = db.getString(getHashIndex('mediaMap', mediaIndex, 'description'));
        // Get the timestamp of this transaction in the mapping
        timestamp = db.getUint(getHashIndex('mediaMap', mediaIndex, 'timestamp'));
        // Get the media hash obtained fro IPFS
        mediaHash = db.getString(getHashIndex('mediaMap', mediaIndex, 'mediaHash'));
        // Get the owner address of the media
        mediaOWner = db.getAddress(getHashIndex('mediaMap', mediaIndex, 'mediaOwner'));

        return (isVideo, title, description, timestamp, mediaHash, mediaOwner);
    }

    /** @dev Returns all the information stored about a media file given a media owner and 
    * the index of the media file in user's media array.
    * @param mediaOwner Address of the media owner.
    * @param mediaIndex - Index of saved media file in user's media array.
    * @return the media file is a video (isVideo).
    * @return associated title of the media file (title).
    * @return associated description of the media file (description).
    * @return the timestamp when media file was saved in the blockchain.
    * @return the media file hash obtained fro IPFS.
    * @return the address of the owner of this media file.
    */
    function getUserMedia(address mediaOwner, uint mediaIndex) public view returns (
        bool isVideo,
        string title,
        string description,
        uint timestamp,
        string mediaHash,
        address mediaOwner
    ) {
        // Get the user media index from user's media array
        uint userMediaIndex = db.getUint(getHashIndex('userMediaMap', mediaOWner, 'userMediaIndex'));
        // Get the media index associated form the users's media array
        uint _mediaIndex = db.getUint(getHashIndex('userMediaMap', mediaOwner, mediaIndex));
        // verify the index and check for overflow/underflow.
        require(mediaIndex <= userMediaIndex.sub(1));

        // return the associated media file.
        return getMedia(_mediaIndex);
    }

    /** @dev Shortcut utility function to check wether a media file hash has been inserted
    * in the storage using the IPFS media file hash to check for existence.
    * @param mediaHash the IPFS file hash to verify.
    * @return boolean indicating if media file exists.
    */
    function checkIfExists(string mediaHash) public view returns (bool mediaExists) {
        mediaExists = db.getUint(getHashIndex('mediaHashMap', mediaHash)) > 0;
    }

    /** @dev Shortcut utility function to read a media file's index by its hash.
    * @param mediaHash the IPFS media file hash registered.
    * @return uint media file index if exists or zero (0).
    */
    function getMediaIndexByHash(string mediaHash) public view returns (uint mediaIndex) {
        mediaIndex = db.getUint(getMediaIndexByHash('mediaHashMap', mediaHash));
    }

    /** @dev Shortcut utility function to check wether a media file hash has been inserted
    * in the storage using the IPFS media file hash to check for existence.
    * @param publicHash the public media file hash computed when the media was added
    * to the blockchain by its owner.
    * @return boolean indicating if media file exists.
    */
    function checkIfExistsByPublicHash(string publicHash) public view returns (bool mediaExists) {
        mediaExists = db.getUint(publicHash) > 0;
    }

    /** @dev Shortcut utility function to read a media file's index by its hash.
    * @param publicHash the public media file hash computed when the media was added
    * to the blockchain by its owner.
    * @return uint media file index if exists or zero (0).
    */
    function getMediaIndexByPublicHash(string publicHash) public view returns (uint mediaIndex) {
        mediaIndex = db.getUint(publicHash);
    }

    /** @dev Shortcut utility function to get all the information of a given media file
    * by using its media hash to obtain the data.
    * @param publicHash the IPFS media file hash saved.
    * @return the media file is a video (isVideo).
    * @return associated title of the media file (title).
    * @return associated description of the media file (description).
    * @return the timestamp when media file was saved in the blockchain.
    * @return the media file hash obtained fro IPFS.
    * @return the address of the owner of this media file.
    */
    function getMediaByPublicHash(string publicHash) public view returns (
        bool isVideo,
        string title,
        string description,
        uint timestamp,
        string mediaHash,
        address mediaOwner
    ) {
        return getMedia(getMediaIndexByPublicHash(publicHash));
    }

    /** @dev Reads the last inserted media file index from storage.
    * @return Last inserted media file index.
    */
    function lastMediaIndex() public view returns (uint) {
        return db.getUint(getHashIndex('lastMediaIndex'));
    }
    
}
