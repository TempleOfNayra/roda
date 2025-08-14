const admin = require('firebase-admin');
const serviceAccount = require('./roda-platform-firebase-adminsdk-f3bxy-be690e8dc5.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRegistrations() {
  const userId = 'yWdnZoEm5rfdFrPbdkLMNXkFo7j2';
  
  console.log('Checking all class_instances...');
  const allInstances = await db.collection('class_instances').get();
  console.log(`Total instances: ${allInstances.size}`);
  
  let registered = 0;
  for (const doc of allInstances.docs) {
    const data = doc.data();
    if (data.attendingStudentIds && data.attendingStudentIds.includes(userId)) {
      registered++;
      console.log(`User registered for instance ${doc.id}:`, {
        scheduledDate: data.scheduledDate.toDate(),
        attendingStudentIds: data.attendingStudentIds
      });
    }
  }
  
  console.log(`\nUser is registered for ${registered} classes`);
  
  process.exit(0);
}

checkRegistrations();
