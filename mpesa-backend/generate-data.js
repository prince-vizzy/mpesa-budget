import axios from 'axios';

const BACKEND_URL = 'http://localhost:5000/api/transactions';

const categories = [
  'Food & Dining',
  'Transport',
  'Shopping',
  'Entertainment',
  'Utilities',
  'Healthcare',
  'Other'
];

const descriptions = {
  'Food & Dining': ['Coffee at Brew', 'Lunch with team', 'Dinner', 'Breakfast items', 'Snacks'],
  'Transport': ['Uber ride', 'Taxi to airport', 'Fuel at Shell', 'Bus fare', 'Parking fees'],
  'Shopping': ['Clothes from Jumia', 'Electronics', 'Groceries', 'Books', 'Shoes from Nakumatt'],
  'Entertainment': ['Movie tickets', 'Concert', 'Gaming', 'Sports event', 'Netflix subscription'],
  'Utilities': ['Internet bill', 'Electricity payment', 'Water bill', 'Gas refill', 'Phone airtime'],
  'Healthcare': ['Doctor visit', 'Pharmacy drugs', 'Dental checkup', 'Health checkup', 'Medicine'],
  'Other': ['Miscellaneous', 'Donation', 'Subscription', 'Repair service', 'Other expense']
};

const amounts = {
  'Food & Dining': [350, 450, 550, 1000, 1500],
  'Transport': [250, 350, 500, 800, 1200],
  'Shopping': [750, 1500, 2500, 3000, 5000],
  'Entertainment': [400, 500, 800, 1200],
  'Utilities': [2000, 2500, 3000, 5000],
  'Healthcare': [800, 1200, 1500, 2500],
  'Other': [100, 250, 500, 1000]
};

async function generateRandomData() {
  console.log('🚀 Generating sample M-Pesa transaction data...\n');

  try {
    // Generate 30-50 random transactions
    const transactionCount = Math.floor(Math.random() * 20) + 30;
    let successCount = 0;
    let failCount = 0;

    for (let i = 0; i < transactionCount; i++) {
      const category = categories[Math.floor(Math.random() * categories.length)];
      const description = descriptions[category][Math.floor(Math.random() * descriptions[category].length)];
      const amount = amounts[category][Math.floor(Math.random() * amounts[category].length)];

      // Random date in last 30 days
      const daysAgo = Math.floor(Math.random() * 30);
      const date = new Date();
      date.setDate(date.getDate() - daysAgo);
      date.setHours(Math.floor(Math.random() * 24));
      date.setMinutes(Math.floor(Math.random() * 60));

      const transaction = {
        amount,
        category,
        description,
        phone_number: `+254712${String(Math.floor(Math.random() * 1000000)).padStart(6, '0')}`,
        transaction_type: Math.random() > 0.85 ? 'received' : 'sent',
        status: 'completed',
        date: date.toISOString(),
        mpesa_ref: `${String.fromCharCode(65 + Math.floor(Math.random() * 26))}${String.fromCharCode(65 + Math.floor(Math.random() * 26))}${String(Math.floor(Math.random() * 9999999)).padStart(7, '0')}`
      };

      try {
        const response = await axios.post(BACKEND_URL, transaction);
        successCount++;
        console.log(`✅ [${i + 1}/${transactionCount}] ${category.padEnd(20)} | KES ${String(amount).padEnd(6)} | ${description}`);
      } catch (error) {
        failCount++;
        console.error(`❌ [${i + 1}/${transactionCount}] Failed: ${error.message}`);
      }

      // Small delay to avoid overwhelming server
      await new Promise(resolve => setTimeout(resolve, 50));
    }

    console.log(`\n📊 Generation Complete!`);
    console.log(`   ✅ Success: ${successCount}`);
    console.log(`   ❌ Failed: ${failCount}`);
    console.log(`\n🌐 View your data at: http://localhost:3000`);
  } catch (error) {
    console.error('💥 Fatal error:', error.message);
    process.exit(1);
  }
}

generateRandomData();
