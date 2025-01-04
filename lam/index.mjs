
export const handler = async(event) => {
    try {
        // fetch is available in Node.js 18 and later runtimes
        console.log(event);
    }
    catch (e) {
        console.error(e);
        return 500;
    }
};