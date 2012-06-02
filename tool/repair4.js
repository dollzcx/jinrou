/*
JINROU data fixer
Changes all prizes to 'ownprize'

*/
var user="test", password="test";	//自分でパスワードを入れてね

var mongo=require('mongodb');
var db=new mongo.Db("werewolf",new mongo.Server("localhost",27017));



db.open(function(err,client){
	if(err)console.log(err);
	db.authenticate(user,password,function(err){
		if(err)console.log(err);
		db.collection("users",function(err,col){
			if(err)console.log(err);
			getdb2(col);
		});
	});
});

function getdb2(users){
	users.find({}).each(function(err,user){
		if(!user){
			console.log("user - finished.");
			return
		}
		query={$set:{ownprize:user.prize}}
		users.update({userid:user.userid},query);
	});
}
